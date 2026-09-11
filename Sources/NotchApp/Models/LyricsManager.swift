import Foundation
import SwiftUI
import Combine

public struct LyricLine: Identifiable, Equatable {
    public let id = UUID()
    public let time: Double
    public let endTime: Double
    public let text: String

    public init(time: Double, endTime: Double, text: String) {
        self.time = time
        self.endTime = endTime
        self.text = text
    }
}

@MainActor
public final class LyricsManager: ObservableObject {
    public static let shared = LyricsManager()

    @Published public var currentLine: String = ""
    @Published public var currentDisplayedText: String = ""
    @Published public var isLyricsEnabled: Bool = true
    @Published public var isFetching: Bool = false
    @Published public var hasLyrics: Bool = false

    private var syncedLines: [LyricLine] = []
    private var lyricsCache: [String: [LyricLine]] = [:]
    private var lastRequestedKey: String = ""
    private var fetchTask: Task<Void, Never>?
    private var chunkTransitionTask: Task<Void, Never>?

    // Lead offset (500ms) to eliminate audio latency and match vocal onset
    private let syncLeadOffset: Double = 0.50

    // Monotonic line tracking: strictly prevents any backward jitter
    private var lastActiveIndex: Int = -1

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
        if !isLyricsEnabled {
            currentLine = ""
            currentDisplayedText = ""
            lastActiveIndex = -1
            chunkTransitionTask?.cancel()
            chunkTransitionTask = nil
        } else {
            lastActiveIndex = -1
            updateTime(MediaManager.shared.currentTime)
        }
        MediaManager.shared.updateProgressTicker()
    }

    public func updateTime(_ time: Double) {
        guard isLyricsEnabled, !syncedLines.isEmpty else {
            if !currentLine.isEmpty {
                currentLine = ""
                currentDisplayedText = ""
                lastActiveIndex = -1
                chunkTransitionTask?.cancel()
                chunkTransitionTask = nil
            }
            return
        }

        // Apply lead offset to anticipate vocal onset
        let effectiveTime = time + syncLeadOffset

        // Find current matching line index
        guard let index = syncedLines.lastIndex(where: { $0.time <= effectiveTime }) else {
            // Before first lyric
            if !currentLine.isEmpty {
                currentLine = ""
                currentDisplayedText = ""
                lastActiveIndex = -1
                chunkTransitionTask?.cancel()
                chunkTransitionTask = nil
            }
            return
        }

        let active = syncedLines[index]

        // If the same line is already active, do not re-trigger or restart animations
        if index == lastActiveIndex && currentLine == active.text {
            return
        }

        // Jitter protection: reject small backward time slips (< 3.0s) from AppleScript polling
        if index < lastActiveIndex && abs(effectiveTime - syncedLines[lastActiveIndex].time) < 3.0 {
            return
        }

        lastActiveIndex = index
        self.currentLine = active.text
        self.displayLine(active, at: effectiveTime)
    }

    private func displayLine(_ line: LyricLine, at currentTime: Double) {
        chunkTransitionTask?.cancel()
        chunkTransitionTask = nil

        let cleanText = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let chunks = splitIntoChunks(cleanText, maxChars: 44)

        if chunks.count <= 1 {
            // Line fits cleanly without splitting
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.currentDisplayedText = cleanText
            }
            return
        }

        // Long line with multiple phrases: advance once to the second phrase (NEVER loop back!)
        let totalDuration = max(2.0, line.endTime - line.time)
        let elapsedOnThisLine = max(0.0, currentTime - line.time)
        let part1Duration = totalDuration * 0.48

        if elapsedOnThisLine >= part1Duration {
            // Already past part 1, show part 2
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.currentDisplayedText = chunks.last ?? cleanText
            }
        } else {
            // Show part 1
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.currentDisplayedText = chunks.first ?? cleanText
            }

            // Schedule a one-time forward advance to part 2 (never loop back to part 1!)
            let waitTime = max(0.8, part1Duration - elapsedOnThisLine)
            chunkTransitionTask = Task {
                try? await Task.sleep(for: .milliseconds(Int(waitTime * 1000)))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.currentLine == line.text else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        self.currentDisplayedText = chunks.last ?? cleanText
                    }
                }
            }
        }
    }

    private func splitIntoChunks(_ text: String, maxChars: Int = 44) -> [String] {
        if text.count <= maxChars {
            return [text]
        }

        // Try natural comma / semicolon separation
        let separators = CharacterSet(charactersIn: ",;—–")
        let parts = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            // Split into roughly two equal halves
            let mid = parts.count / 2
            let firstHalf = parts[0..<mid].joined(separator: ", ")
            let secondHalf = parts[mid...].joined(separator: ", ")
            return [firstHalf, secondHalf]
        }

        // Fallback: word-boundary split
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 4 {
            let mid = words.count / 2
            let firstHalf = words[0..<mid].joined(separator: " ")
            let secondHalf = words[mid...].joined(separator: " ")
            return [firstHalf, secondHalf]
        }

        return [text]
    }

    public func fetchLyrics(title: String, artist: String) {
        let cleanTitle = cleanTrackTitle(title)
        let cleanArtist = cleanArtistName(artist)
        let cacheKey = "\(cleanTitle.lowercased())|\(cleanArtist.lowercased())"

        guard !cleanTitle.isEmpty, cleanTitle != "no media playing", cleanTitle != "nothing playing" else {
            self.syncedLines = []
            self.currentLine = ""
            self.currentDisplayedText = ""
            self.hasLyrics = false
            self.lastActiveIndex = -1
            return
        }

        if let cached = lyricsCache[cacheKey] {
            self.syncedLines = cached
            self.hasLyrics = !cached.isEmpty
            self.lastActiveIndex = -1
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
            self.lastActiveIndex = -1
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
        var rawLines: [(time: Double, text: String)] = []
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

                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanText.isEmpty && !cleanText.hasPrefix("[") {
                    rawLines.append((time: totalSecs, text: cleanText))
                }
            }
        }

        let sorted = rawLines.sorted { $0.time < $1.time }
        var result: [LyricLine] = []
        for i in 0..<sorted.count {
            let item = sorted[i]
            let nextTime = (i + 1 < sorted.count) ? sorted[i + 1].time : (item.time + 6.0)
            result.append(LyricLine(time: item.time, endTime: nextTime, text: item.text))
        }
        return result
    }

    private func cleanTrackTitle(_ raw: String) -> String {
        var s = raw
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
