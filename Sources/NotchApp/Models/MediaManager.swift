import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()

    @Published public var title: String = "No Media Playing"
    @Published public var artist: String = "Spotify / Apple Music"
    @Published public var album: String = ""
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var progress: Double = 0
    @Published public var artwork: NSImage? = nil
    @Published public var sourceApp: String = "System"

    private var progressTicker: Timer?
    private var lastArtworkURL: String = ""
    private var hasAppleScriptPermissionDenied: Bool = false
    private let artworkCache = NSCache<NSString, NSImage>()

    // MediaRemote function pointers (Universal macOS media keys - ZERO PERMISSION REQUIRED)
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias MRMediaRemoteSetElapsedTimeFunction = @convention(c) (Double) -> Void

    private var sendCommandFunc: MRMediaRemoteSendCommandFunction?
    private var setElapsedTimeFunc: MRMediaRemoteSetElapsedTimeFunction?

    private init() {
        artworkCache.countLimit = 20
        setupMediaRemote()
        setupDistributedNotifications()
        updateNowPlaying()
    }

    private func setupMediaRemote() {
        guard let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        ) else { return }

        if let sendPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            sendCommandFunc = unsafeBitCast(sendPtr, to: MRMediaRemoteSendCommandFunction.self)
        }
        if let seekPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
            setElapsedTimeFunc = unsafeBitCast(seekPtr, to: MRMediaRemoteSetElapsedTimeFunction.self)
        }
    }

    private func setupDistributedNotifications() {
        // Event-driven: Spotify notification fires when track changes, plays, or pauses
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlaying()
            }
        }

        // Event-driven: Apple Music notification fires on state changes
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlaying()
            }
        }
    }

    // High performance local progress ticker: advances by 0.15s in memory for ultra-smooth real-time lyrics sync
    private func updateProgressTicker() {
        progressTicker?.invalidate()
        progressTicker = nil

        if isPlaying {
            progressTicker = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, self.isPlaying else { return }
                    if self.duration > 0 && self.currentTime < self.duration {
                        self.currentTime += 0.15
                        self.progress = min(1.0, self.currentTime / self.duration)
                        LyricsManager.shared.updateTime(self.currentTime)
                    }
                }
            }
        }
    }

    public func updateNowPlaying() {
        // If user denied AppleScript permissions, don't keep asking or erroring
        if hasAppleScriptPermissionDenied { return }

        // 1. Check if Spotify is running using native Cocoa (ZERO PERMISSION NEEDED)
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        if isSpotifyRunning && updateFromSpotify() {
            return
        }

        // 2. Check if Apple Music is running using native Cocoa (ZERO PERMISSION NEEDED)
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        if isMusicRunning && updateFromMusic() {
            return
        }

        // No desktop app playing
        if !self.isPlaying {
            self.title = "Nothing Playing"
            self.artist = "Play in Spotify or Apple Music"
            self.progress = 0
            self.artwork = nil
            self.sourceApp = "System"
            LyricsManager.shared.updateTime(0)
            updateProgressTicker()
        }
    }

    // MARK: - Spotify Detection (Only queried if Spotify is verified running)
    private func updateFromSpotify() -> Bool {
        let script = """
        tell application "Spotify"
            try
                set pState to (player state as string)
                set tName to (name of current track as string)
                set tArtist to (artist of current track as string)
                set tAlbum to (album of current track as string)
                set tPos to (player position as string)
                set tDur to (duration of current track as string)
                set tArt to (artwork url of current track as string)
                return (pState & "||" & tName & "||" & tArtist & "||" & tAlbum & "||" & tPos & "||" & tDur & "||" & tArt)
            on error errText number errNum
                if errNum is -1743 then
                    return "DENIED"
                end if
                return ""
            end try
        end tell
        """

        guard let output = runAppleScript(script), !output.isEmpty else { return false }
        if output == "DENIED" {
            self.hasAppleScriptPermissionDenied = true
            return false
        }

        let parts = output.components(separatedBy: "||")
        guard parts.count >= 7 else { return false }

        let stateStr = parts[0]
        self.isPlaying = (stateStr == "playing")
        self.title = parts[1]
        self.artist = parts[2]
        self.album = parts[3]
        self.sourceApp = "Spotify"

        let posStr = parts[4].replacingOccurrences(of: ",", with: ".")
        self.currentTime = Double(posStr) ?? 0

        if let durMs = Double(parts[5].replacingOccurrences(of: ",", with: ".")) {
            self.duration = durMs > 1000 ? (durMs / 1000.0) : durMs
        }

        if self.duration > 0 {
            self.progress = min(1.0, max(0.0, self.currentTime / self.duration))
        }

        let artURL = parts[6].trimmingCharacters(in: .whitespacesAndNewlines)
        if !artURL.isEmpty && artURL != self.lastArtworkURL {
            self.lastArtworkURL = artURL
            fetchArtwork(from: artURL)
        }

        LyricsManager.shared.fetchLyrics(title: self.title, artist: self.artist)
        LyricsManager.shared.updateTime(self.currentTime)
        updateProgressTicker()
        return true
    }

    // MARK: - Apple Music Detection
    private func updateFromMusic() -> Bool {
        let script = """
        tell application "Music"
            try
                set pState to (player state is playing)
                set tName to (name of current track as string)
                set tArtist to (artist of current track as string)
                set tAlbum to (album of current track as string)
                set tPos to (player position as string)
                set tDur to (duration of current track as string)
                return ((pState as string) & "||" & tName & "||" & tArtist & "||" & tAlbum & "||" & tPos & "||" & tDur)
            on error errText number errNum
                if errNum is -1743 then
                    return "DENIED"
                end if
                return ""
            end try
        end tell
        """

        guard let output = runAppleScript(script), !output.isEmpty else { return false }
        if output == "DENIED" {
            self.hasAppleScriptPermissionDenied = true
            return false
        }

        let parts = output.components(separatedBy: "||")
        guard parts.count >= 6 else { return false }

        self.isPlaying = (parts[0].lowercased() == "true")
        self.title = parts[1]
        self.artist = parts[2]
        self.album = parts[3]
        self.sourceApp = "Apple Music"

        let posStr = parts[4].replacingOccurrences(of: ",", with: ".")
        self.currentTime = Double(posStr) ?? 0

        let durStr = parts[5].replacingOccurrences(of: ",", with: ".")
        self.duration = Double(durStr) ?? 0

        if self.duration > 0 {
            self.progress = min(1.0, max(0.0, self.currentTime / self.duration))
        }

        LyricsManager.shared.fetchLyrics(title: self.title, artist: self.artist)
        LyricsManager.shared.updateTime(self.currentTime)
        updateProgressTicker()
        return true
    }

    // MARK: - Media Controls (Explicitly targets the displayed app)
    public func togglePlayPause() {
        if sourceApp == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        } else if sourceApp == "Apple Music" {
            _ = runAppleScript("tell application \"Music\" to playpause")
        } else if let send = sendCommandFunc {
            _ = send(2, nil) // 2 = TogglePlayPause (Universal fallback)
        }

        isPlaying.toggle()
        updateProgressTicker()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updateNowPlaying()
        }
    }

    public func nextTrack() {
        if sourceApp == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to next track")
        } else if sourceApp == "Apple Music" {
            _ = runAppleScript("tell application \"Music\" to next track")
        } else if let send = sendCommandFunc {
            _ = send(4, nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.updateNowPlaying()
        }
    }

    public func previousTrack() {
        if sourceApp == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        } else if sourceApp == "Apple Music" {
            _ = runAppleScript("tell application \"Music\" to previous track")
        } else if let send = sendCommandFunc {
            _ = send(5, nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.updateNowPlaying()
        }
    }

    public func seek(to progressPercent: Double) {
        let newTime = duration * progressPercent
        self.currentTime = newTime
        self.progress = progressPercent
        LyricsManager.shared.updateTime(newTime)

        if sourceApp == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(newTime)")
        } else if sourceApp == "Apple Music" {
            _ = runAppleScript("tell application \"Music\" to set player position to \(newTime)")
        } else if let seek = setElapsedTimeFunc {
            seek(newTime)
        }
    }

    // High performance memory cached artwork loader
    private func fetchArtwork(from urlString: String) {
        let key = urlString as NSString
        if let cached = artworkCache.object(forKey: key) {
            self.artwork = cached
            return
        }

        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil, let img = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.artworkCache.setObject(img, forKey: urlString as NSString)
                self?.artwork = img
            }
        }.resume()
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: source) else { return nil }
        let output = scriptObject.executeAndReturnError(&error)
        if error != nil { return nil }
        return output.stringValue
    }

    public func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
