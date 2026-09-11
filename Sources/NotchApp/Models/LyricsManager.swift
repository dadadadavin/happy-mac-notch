import Foundation
import SwiftUI
import Combine

public struct LyricLine: Identifiable, Equatable {
    public let id = UUID()
    public let time: Double
    public let text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

@MainActor
public final class LyricsManager: ObservableObject {
    public static let shared = LyricsManager()

    @Published public var currentLine: String = ""
    @Published public var isLyricsEnabled: Bool = true
    @Published public var isFetching: Bool = false
    @Published public var hasLyrics: Bool = false

    private var syncedLines: [LyricLine] = []
    private var lyricsCache: [String: [LyricLine]] = [:]
    private var lastRequestedKey: String = ""
    private var fetchTask: Task<Void, Never>?

    private init() {
        if UserDefaults.standard.object(forKey: "enableLiveLyrics") != nil {
            self.isLyricsEnabled = UserDefaults.standard.bool(forKey: "enableLiveLyrics")
        } else {
            self.isLyricsEnabled = true
        }
    }

    public func toggleLyrics() {
        isLyricsEnabled.toggle()
        UserDefaults.standard.set(isLyricsEnabled, forKey: "enableLiveLyrics")
    }

    public func updateTime(_ time: Double) {
        guard isLyricsEnabled, !syncedLines.isEmpty else {
            if !currentLine.isEmpty {
                currentLine = ""
            }
            return
        }

        // Match current line with 0.25s lookahead tolerance for smooth transition
        if let active = syncedLines.last(where: { $0.time <= time + 0.25 }) {
            let clean = active.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentLine != clean {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.currentLine = clean
                }
            }
        } else {
            if !currentLine.isEmpty {
                currentLine = ""
            }
        }
    }

    public func fetchLyrics(title: String, artist: String) {
        let cleanTitle = cleanTrackTitle(title)
        let cleanArtist = cleanArtistName(artist)
        let cacheKey = "\(cleanTitle.lowercased())|\(cleanArtist.lowercased())"

        guard !cleanTitle.isEmpty, cleanTitle != "no media playing", cleanTitle != "nothing playing" else {
            self.syncedLines = []
            self.currentLine = ""
            self.hasLyrics = false
            return
        }

        if let cached = lyricsCache[cacheKey] {
            self.syncedLines = cached
            self.hasLyrics = !cached.isEmpty
            self.updateTime(MediaManager.shared.currentTime)
            return
        }

        if lastRequestedKey == cacheKey && isFetching { return }
        lastRequestedKey = cacheKey

        fetchTask?.cancel()
        fetchTask = Task {
            self.isFetching = true
            let lines = await self.performSearch(title: cleanTitle, artist: cleanArtist)
            guard !Task.isCancelled else { return }

            self.lyricsCache[cacheKey] = lines
            self.syncedLines = lines
            self.hasLyrics = !lines.isEmpty
            self.isFetching = false
            self.updateTime(MediaManager.shared.currentTime)
        }
    }

    private func performSearch(title: String, artist: String) async -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        var queryItems = [URLQueryItem(name: "track_name", value: title)]
        if !artist.isEmpty && artist != "Spotify / Apple Music" && artist != "System" {
            queryItems.append(URLQueryItem(name: "artist_name", value: artist))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("HappyMacNotch/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            struct Item: Decodable {
                let syncedLyrics: String?
                let plainLyrics: String?
            }

            let items = try JSONDecoder().decode([Item].self, from: data)
            if let firstSynced = items.first(where: { ($0.syncedLyrics ?? "").count > 10 }),
               let syncedText = firstSynced.syncedLyrics {
                return parseLRC(syncedText)
            } else if let first = items.first, let synced = first.syncedLyrics, !synced.isEmpty {
                return parseLRC(synced)
            }
        } catch {
            return []
        }

        return []
    }

    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let ns = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let minStr = ns.substring(with: match.range(at: 1))
                let secStr = ns.substring(with: match.range(at: 2))
                var csVal = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let csStr = ns.substring(with: match.range(at: 3))
                    csVal = (Double(csStr) ?? 0.0) / (csStr.count == 3 ? 1000.0 : 100.0)
                }

                let text = match.range(at: 4).location != NSNotFound ? ns.substring(with: match.range(at: 4)) : ""
                let minutes = Double(minStr) ?? 0
                let seconds = Double(secStr) ?? 0
                let totalSecs = minutes * 60.0 + seconds + csVal

                // Skip instrumental marks or headers
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanText.isEmpty && !cleanText.hasPrefix("[") {
                    lines.append(LyricLine(time: totalSecs, text: cleanText))
                }
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    private func cleanTrackTitle(_ raw: String) -> String {
        var s = raw
        // Remove remaster / edition tags
        let patterns = [
            #"\s*-\s*Remaster(ed)?(\s*\d{4})?"#,
            #"\s*\([^\)]*Remaster[^\)]*\)"#,
            #"\s*\[[^\]]*Remaster[^\]]*\]"#,
            #"\s*-\s*Deluxe(\s*Edition)?"#,
            #"\s*\([^\)]*feat\.[^\)]*\)"#,
            #"\s*\[[^\]]*feat\.[^\)]*\]"#,
            #"\s*-\s*Live.*$"#
        ]
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                s = regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: "")
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanArtistName(_ raw: String) -> String {
        var s = raw
        if let firstComma = s.firstIndex(of: ",") {
            s = String(s[..<firstComma])
        }
        if let firstSemi = s.firstIndex(of: ";") {
            s = String(s[..<firstSemi])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
