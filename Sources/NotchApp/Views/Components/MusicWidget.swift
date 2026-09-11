import SwiftUI

public struct MusicWidget: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var media = MediaManager.shared
    @ObservedObject var lyrics = LyricsManager.shared
    @State private var isPlayHovered: Bool = false
    @State private var isPrevHovered: Bool = false
    @State private var isNextHovered: Bool = false

    public init(vm: NotchViewModel) {
        self.vm = vm
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Album Artwork (Apple Continuous Squircle with Ambient Shadow)
            ZStack {
                if let nsImg = media.artwork {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 3)
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (media.sourceApp == "Spotify" ? Color.green : Color.pink).opacity(0.8),
                                    Color.black.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                        .shadow(color: (media.sourceApp == "Spotify" ? Color.green : Color.pink).opacity(0.3), radius: 6, x: 0, y: 2)

                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Song Info & Dynamic Island Controls
            VStack(alignment: .leading, spacing: 5) {
                // ROW 1: Title, Artist, Lyrics toggle & Equalizer
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.title.isEmpty ? "No Track Playing" : media.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(media.artist.isEmpty ? "Play in Spotify or Apple Music" : media.artist)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)

                            if !media.sourceApp.isEmpty && media.sourceApp != "System" {
                                Text("• " + media.sourceApp)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(media.sourceApp == "Spotify" ? Color.green : Color.pink)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 7) {
                        // Lyrics Toggle Button
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                lyrics.toggleLyrics()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: lyrics.isLyricsEnabled ? "quote.bubble.fill" : "quote.bubble")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Lyrics")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(lyrics.isLyricsEnabled ? Color.white : Color.white.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(lyrics.isLyricsEnabled
                                          ? (media.sourceApp == "Spotify" ? Color.green.opacity(0.35) : Color.pink.opacity(0.35))
                                          : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .help(lyrics.isLyricsEnabled ? "Turn off live lyrics" : "Turn on live lyrics")

                        // Animated Live Equalizer (never stuck as dots)
                        EqualizerBars(
                            isPlaying: media.isPlaying,
                            color: media.sourceApp == "Spotify" ? Color.green : (media.sourceApp == "Apple Music" ? Color.pink : Color.white.opacity(0.8))
                        )
                    }
                }

                // ROW 2: Live Lyric Preview line (when enabled and present)
                if lyrics.isLyricsEnabled && !lyrics.currentDisplayedText.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "music.note")
                            .font(.system(size: 8))
                            .foregroundStyle(media.sourceApp == "Spotify" ? Color.green : Color.pink)
                        Text(lyrics.currentDisplayedText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .offset(y: 2)))
                }

                // ROW 3: Interactive Progress Scrubber with Timestamps
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 3.5)

                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(0, geo.size.width * CGFloat(media.progress)), height: 3.5)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let pct = max(0.0, min(1.0, Double(value.location.x / geo.size.width)))
                                    media.seek(to: pct)
                                }
                        )
                    }
                    .frame(height: 5)

                    HStack {
                        Text(media.formatTime(media.currentTime))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))

                        Spacer()

                        Text(media.formatTime(media.duration))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                // ROW 4: Centered Playback Transport Controls
                HStack(spacing: 24) {
                    Spacer()

                    // Previous Track
                    Button(action: {
                        media.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(isPrevHovered ? Color.white : Color.white.opacity(0.75))
                            .scaleEffect(isPrevHovered ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) { isPrevHovered = hovering }
                    }

                    // Prominent Play/Pause (Apple White Circle Button)
                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                            media.togglePlayPause()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                                .shadow(color: Color.black.opacity(0.35), radius: 4, y: 1)

                            Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)
                                .offset(x: media.isPlaying ? 0 : 1)
                        }
                        .scaleEffect(isPlayHovered ? 1.06 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) { isPlayHovered = hovering }
                    }

                    // Next Track
                    Button(action: {
                        media.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(isNextHovered ? Color.white : Color.white.opacity(0.75))
                            .scaleEffect(isNextHovered ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) { isNextHovered = hovering }
                    }

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 14)
    }
}

// MARK: - Mini Animated Equalizer Bars (Live Dynamic Audio Wave)
struct EqualizerBars: View {
    let isPlaying: Bool
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 2.2) {
            bar(delay: 0.0, minH: 3.5, maxH: 10.0)
            bar(delay: 0.14, minH: 5.0, maxH: 14.0)
            bar(delay: 0.08, minH: 3.5, maxH: 8.5)
            bar(delay: 0.22, minH: 4.5, maxH: 12.0)
        }
        .frame(height: 14)
        .onAppear {
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    phase = 0
                }
            }
        }
    }

    @ViewBuilder
    private func bar(delay: Double, minH: CGFloat, maxH: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 2.2, height: isPlaying ? (phase == 1 ? maxH : minH) : minH)
            .animation(
                isPlaying
                    ? .easeInOut(duration: 0.42).repeatForever(autoreverses: true).delay(delay)
                    : .easeOut(duration: 0.2),
                value: phase
            )
            .opacity(isPlaying ? 1.0 : 0.4)
    }
}
