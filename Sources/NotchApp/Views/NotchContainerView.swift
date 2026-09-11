import SwiftUI
import UniformTypeIdentifiers

public struct NotchContainerView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var media = MediaManager.shared
    @ObservedObject var vitals = SystemVitalsManager.shared
    @ObservedObject var lyrics = LyricsManager.shared
    @State private var isCloseHovered: Bool = false

    public init(vm: NotchViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 1. Center Hardware Notch Container
                ZStack(alignment: .top) {
                    // Background notch shape with continuous curve
                    NotchShape(
                        topCornerRadius: vm.topRadius,
                        bottomCornerRadius: vm.bottomRadius
                    )
                    .fill(Color.black)
                    .shadow(
                        color: (vm.state == .open || vm.isHovering) ? Color.black.opacity(0.7) : Color.clear,
                        radius: 12,
                        y: 6
                    )

                    // Top bezel cover line (ensures pixel-perfect fusion with Mac bezel)
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                        .padding(.horizontal, vm.topRadius)

                    // Content Layer
                    VStack(spacing: 0) {
                        if vm.state == .open {
                            expandedView
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        } else {
                            idleView
                                .transition(.opacity)
                        }
                    }
                }
                .frame(width: vm.currentWidth, height: vm.currentHeight, alignment: .top)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if vm.state == .open {
                        vm.handleHover(hovering)
                    }
                }
                .onTapGesture {
                    vm.toggleOpen()
                }
                .onDrop(of: [.fileURL, .url], delegate: NotchDropDelegate(vm: vm))

                // 2. Floating Live Lyrics Pill (Positioned strictly to the LEFT of the closed notch, with 20pt clear margin)
                if vm.state == .closed && lyrics.isLyricsEnabled && media.isPlaying && !lyrics.currentDisplayedText.isEmpty {
                    HStack(spacing: 0) {
                        Spacer()

                        LiveLyricsPillView(lyrics: lyrics, media: media) {
                            vm.toggleOpen()
                        }
                        .padding(.trailing, (vm.geometry.physicalSize.width / 2.0) + 20)
                    }
                    .frame(width: 430, height: vm.geometry.physicalSize.height)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .trailing)),
                        removal: .opacity
                    ))
                }
            }
            .frame(width: 860, alignment: .top)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    // Closed / Idle mini view (Apple Dynamic Island Style)
    private var idleView: some View {
        HStack {
            if media.isPlaying {
                HStack(spacing: 5) {
                    Circle()
                        .fill(media.sourceApp == "Spotify" ? Color.green : Color.pink)
                        .frame(width: 7, height: 7)
                }
                .padding(.leading, 12)
            } else {
                // Subtle Hardware SOC Temperature indicator
                HStack(spacing: 3) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.cyan)
                    Text(String(format: "%.0f°", vitals.socTemperature))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.leading, 10)
            }

            Spacer()

            if media.isPlaying {
                // Mini sound wave indicator
                HStack(spacing: 2.5) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 8)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 12)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 6)
                }
                .padding(.trailing, 12)
            } else {
                // Subtle Battery indicator
                HStack(spacing: 3) {
                    Text("\(vitals.batteryLevel)%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Image(systemName: vitals.isCharging ? "bolt.fill" : (vitals.batteryLevel > 20 ? "battery.100" : "battery.25"))
                        .font(.system(size: 9))
                        .foregroundStyle(vitals.isCharging ? Color.yellow : (vitals.batteryLevel > 20 ? Color.green : Color.red))
                }
                .padding(.trailing, 10)
            }
        }
        .frame(height: vm.geometry.physicalSize.height)
    }

    // Expanded full panel view (Apple Control Center / Dynamic Island style)
    private var expandedView: some View {
        VStack(spacing: 2) {
            // TOP HEADER ROW (flanking the physical notch neatly)
            HStack(spacing: 0) {
                // Left Wing: Music & Drop Shelf tabs centered neatly in the left wing
                HStack(spacing: 8) {
                    tabButton(for: .music)
                    tabButton(for: .dropZone)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // CENTER: PHYSICAL HARDWARE NOTCH HOLE
                // Empty black space matching the exact notch width so the camera is bypassed
                Rectangle()
                    .fill(Color.black)
                    .frame(width: vm.geometry.physicalSize.width, height: vm.geometry.physicalSize.height)

                // Right Wing: Stats tab and Close button centered neatly
                HStack(spacing: 12) {
                    tabButton(for: .stats)

                    Button(action: {
                        vm.toggleOpen()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isCloseHovered ? Color.white : Color.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(isCloseHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) { isCloseHovered = hovering }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: vm.geometry.physicalSize.height)

            // CONTENT CARD (Directly below the notch, snug and compact)
            Group {
                switch vm.activeTab {
                case .music:
                    MusicWidget(vm: vm)
                case .dropZone:
                    DropZoneWidget(vm: vm)
                case .stats:
                    SystemStatsWidget(vm: vm)
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func tabButton(for tab: ActiveTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.activeTab = tab
            }
        }) {
            HStack(spacing: 4.5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: vm.activeTab == tab ? .semibold : .medium, design: .rounded))
            }
            .foregroundStyle(vm.activeTab == tab ? Color.white : Color.white.opacity(0.6))
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(vm.activeTab == tab ? Color.white.opacity(0.22) : Color.clear)
                    .shadow(color: vm.activeTab == tab ? Color.black.opacity(0.25) : Color.clear, radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notch Container Drop Delegate
private struct NotchDropDelegate: DropDelegate {
    @ObservedObject var vm: NotchViewModel

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL, .url])
    }

    func dropEntered(info: DropInfo) {
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.8)) {
            vm.state = .open
            vm.activeTab = .dropZone
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL, .url])
        guard !providers.isEmpty else { return false }
        DropFileLoader.loadFiles(from: providers) { url in
            vm.addDroppedFile(url)
        }
        return true
    }
}

// MARK: - Live Lyrics Floating Pill Component
public struct LiveLyricsPillView: View {
    @ObservedObject var lyrics: LyricsManager
    @ObservedObject var media: MediaManager
    var onTap: () -> Void

    public var body: some View {
        HStack(spacing: 7) {
            // Live animated equalizer wave bars
            LiveLyricWave(
                isPlaying: media.isPlaying,
                color: media.sourceApp == "Spotify" ? Color.green : Color.pink
            )

            // The lyric text (with smooth vertical glide transition, no ellipsis)
            Text(lyrics.currentDisplayedText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .id(lyrics.currentDisplayedText)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 4)),
                    removal: .opacity.combined(with: .offset(y: -4))
                ))
        }
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.42))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    (media.sourceApp == "Spotify" ? Color.green : Color.pink).opacity(0.30)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 0.6
                        )
                )
        )
        .shadow(color: (media.sourceApp == "Spotify" ? Color.green : Color.pink).opacity(0.25), radius: 6, y: 1)
        .contentShape(Capsule())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Live Lyric Dancing Wave Icon
public struct LiveLyricWave: View {
    let isPlaying: Bool
    let color: Color
    @State private var phase: CGFloat = 0

    public var body: some View {
        HStack(spacing: 2) {
            bar(delay: 0.0, minH: 3.5, maxH: 9.5)
            bar(delay: 0.15, minH: 5.5, maxH: 13.0)
            bar(delay: 0.3, minH: 3.5, maxH: 8.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    @ViewBuilder
    private func bar(delay: Double, minH: CGFloat, maxH: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 2, height: isPlaying ? (phase == 1 ? maxH : minH) : minH)
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(delay), value: phase)
    }
}

