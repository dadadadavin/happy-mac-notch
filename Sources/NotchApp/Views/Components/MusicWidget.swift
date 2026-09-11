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
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 3)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.black.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 2)

                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Song Info & Dynamic Island Controls
            VStack(alignment: .leading, spacing: 4) {
                // Title, Lyrics toggle & Equalizer
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(media.artist)
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

                    Spacer()

                    HStack(spacing: 8) {
                        // Lyrics Toggle Button
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                lyrics.toggleLyrics()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: lyrics.isLyricsEnabled ? "quote.bubble.fill" : "quote.bubble")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Lyrics")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(lyrics.isLyricsEnabled ? Color.white : Color.white.opacity(0.45))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(lyrics.isLyricsEnabled
                                          ? (media.sourceApp == "Spotify" ? Color.green.opacity(0.35) : Color.pink.opacity(0.35))
                                          : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .help(lyrics.isLyricsEnabled ? "Turn off live lyrics" : "Turn on live lyrics")

                        // Mini sound wave visualizer
                        EqualizerBars(isPlaying: media.isPlaying)
                            .padding(.trailing, 2)
                    }
                }

                // In-Widget Live Lyric Preview (when lyrics enabled)
                if lyrics.isLyricsEnabled && !lyrics.currentLine.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 8))
                            .foregroundStyle(media.sourceApp == "Spotify" ? Color.green : Color.pink)
                        Text(lyrics.currentLine)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .transition(.opacity)
                }

                // Interactive Progress Scrubber (Apple Style Thin Track)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
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
                .frame(height: 6)

                // Controls Row (Apple Symmetrical Centered Layout)
                HStack(spacing: 0) {
                    Text(media.formatTime(media.currentTime))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 34, alignment: .leading)

                    Spacer()

                    HStack(spacing: 18) {
                        // Previous
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
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, y: 1)

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

                        // Next
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
                    }

                    Spacer()

                    Text(media.formatTime(media.duration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 34, alignment: .trailing)
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

// Mini animated equalizer bars
struct EqualizerBars: View {
    let isPlaying: Bool
    @State private var bar1: CGFloat = 0.4
    @State private var bar2: CGFloat = 0.8
    @State private var bar3: CGFloat = 0.3

    var body: some View {
        HStack(spacing: 3) {
            barView(height: bar1)
            barView(height: bar2)
            barView(height: bar3)
        }
        .frame(height: 13)
        .onAppear {
            animateBars()
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                animateBars()
            }
        }
    }

    private func barView(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.green.opacity(0.9))
            .frame(width: 3, height: isPlaying ? max(3, height * 13) : 3)
            .animation(
                isPlaying
                    ? .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
                    : .default,
                value: height
            )
    }

    private func animateBars() {
        guard isPlaying else { return }
        bar1 = 0.9
        bar2 = 0.3
        bar3 = 0.8
    }
}
