import SwiftUI
import AVFoundation
import AppKit

public struct MirrorWidget: View {
    @ObservedObject var vm: NotchViewModel
    @StateObject private var camera = CameraManager.shared

    @State private var copyFeedback: Bool = false
    @State private var saveFeedback: Bool = false
    @State private var isShutterHovered: Bool = false
    @State private var isCopyHovered: Bool = false
    @State private var isSaveHovered: Bool = false
    @State private var isRetakeHovered: Bool = false
    @State private var isPreviewHovered: Bool = false

    public init(vm: NotchViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            // Background container matching DropZone and MusicWidget
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            if camera.authorizationStatus == .denied || camera.authorizationStatus == .restricted {
                permissionDeniedView
            } else if let captured = camera.capturedImage {
                if camera.isEnlarged {
                    enlargedCapturedView(image: captured)
                } else {
                    compactCapturedView(image: captured)
                }
            } else {
                if camera.isEnlarged {
                    enlargedLiveView
                } else {
                    compactLiveView
                }
            }
        }
        .frame(height: camera.isEnlarged ? 218 : 88)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .onAppear {
            camera.startSession()
        }
        .onDisappear {
            camera.stopSession()
        }
    }

    // MARK: - Compact Live Viewfinder (Normal 88pt)
    private var compactLiveView: some View {
        HStack(spacing: 14) {
            // Camera Preview (Click to Enlarge)
            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    camera.isEnlarged = true
                }
            }) {
                ZStack(alignment: .bottomTrailing) {
                    CameraPreviewView(session: camera.captureSession)
                        .frame(width: 146, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isPreviewHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .accessibilityLabel("Quick Mirror Camera Preview")

                    // Top indicator: "Look up at Notch"
                    VStack {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                            Text("Look at Lens")
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .padding(.top, 4)

                        Spacer()
                    }

                    // Expand button badge in bottom-right corner
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                        Text("Enlarge")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(isPreviewHovered ? 1.0 : 0.75))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(4)

                    // Countdown overlay if active
                    if camera.isCountingDown {
                        ZStack {
                            Color.black.opacity(0.4)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text("\(camera.countdownRemaining)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .cyan.opacity(0.8), radius: 10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Shutter flash effect
                    if camera.isFlashing {
                        Color.white
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .transition(.opacity)
                    }
                }
                .frame(width: 146, height: 76)
            }
            .buttonStyle(.plain)
            .onHover { isPreviewHovered = $0 }
            .help("Click preview to enlarge mirror")

            // Right side: controls & actions
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(camera.isSessionRunning ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text("Quick Mirror")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Timer toggle button (Instant / 3s)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            camera.useTimer.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: camera.useTimer ? "timer" : "bolt.slash")
                                .font(.system(size: 9))
                            Text(camera.useTimer ? "3s Timer" : "Instant")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(camera.useTimer ? Color.yellow : Color.white.opacity(0.6))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(camera.useTimer ? Color.yellow.opacity(0.15) : Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .help(camera.useTimer ? "Self-timer enabled (3 seconds)" : "Instant capture on click")
                    .accessibilityLabel("Toggle 3-second selfie timer")
                }

                HStack(spacing: 12) {
                    // Shutter button (Spacebar shortcut)
                    Button(action: {
                        camera.triggerShutter()
                    }) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                                    .frame(width: 26, height: 26)

                                Circle()
                                    .fill(isShutterHovered ? Color.white : Color.white.opacity(0.85))
                                    .frame(width: 18, height: 18)
                            }

                            Text(camera.isCountingDown ? "Snapping in \(camera.countdownRemaining)s..." : "Take Selfie")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(isShutterHovered ? 0.22 : 0.14))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(camera.isCountingDown || camera.isCapturing)
                    .help("Snap photo (Spacebar)")
                    .accessibilityLabel("Take Selfie")
                    .onHover { isShutterHovered = $0 }

                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            camera.isEnlarged = true
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9))
                            Text("Enlarge")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color.white.opacity(0.65))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Make mirror view larger")
                }
            }
            .padding(.trailing, 10)

            Spacer()
        }
        .padding(.leading, 8)
    }

    // MARK: - Enlarged Live Viewfinder (High-Detail 218pt)
    private var enlargedLiveView: some View {
        VStack(spacing: 8) {
            // Big Viewfinder directly centered beneath the hardware notch lens
            ZStack(alignment: .topTrailing) {
                // Viewfinder preview as a plain button to click-to-shrink
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        camera.isEnlarged = false
                    }
                }) {
                    CameraPreviewView(session: camera.captureSession)
                        .frame(width: 440, height: 155)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isPreviewHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isPreviewHovered = $0 }
                .help("Click preview to shrink back to compact mirror")

                // Top Look at Lens indicator (allowsHitTesting false so clicks pass through to preview)
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                        Text("Look directly at Notch Lens")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(.top, 6)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Top-right shrink button
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        camera.isEnlarged = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 9, weight: .bold))
                        Text("Compact")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .padding(6)
                }
                .buttonStyle(.plain)
                .help("Click to shrink back to compact mirror")

                // Countdown overlay if active
                if camera.isCountingDown {
                    ZStack {
                        Color.black.opacity(0.4)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Text("\(camera.countdownRemaining)")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.9), radius: 14)
                            .transition(.scale.combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }

                // Shutter flash effect
                if camera.isFlashing {
                    Color.white
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 440, height: 155)

            // Bottom controls toolbar
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(camera.isSessionRunning ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text("Expanded Mirror")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                // Timer toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        camera.useTimer.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: camera.useTimer ? "timer" : "bolt.slash")
                            .font(.system(size: 10))
                        Text(camera.useTimer ? "3s Timer Active" : "Instant Snap")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(camera.useTimer ? Color.yellow : Color.white.opacity(0.7))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(camera.useTimer ? Color.yellow.opacity(0.18) : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                // Big Shutter button (Spacebar)
                Button(action: {
                    camera.triggerShutter()
                }) {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                .frame(width: 26, height: 26)

                            Circle()
                                .fill(isShutterHovered ? Color.white : Color.white.opacity(0.85))
                                .frame(width: 18, height: 18)
                        }

                        Text(camera.isCountingDown ? "Snapping in \(camera.countdownRemaining)s..." : "Take Selfie")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.white.opacity(isShutterHovered ? 0.25 : 0.16))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .disabled(camera.isCountingDown || camera.isCapturing)
                .onHover { isShutterHovered = $0 }
            }
            .frame(width: 440)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Compact Captured Photo Preview
    private func compactCapturedView(image: NSImage) -> some View {
        HStack(spacing: 14) {
            // Photo thumbnail with drag support
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 146, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Drag indicator badge
                HStack(spacing: 3) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 8))
                    Text("Drag out")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.7)))
                .padding(4)
            }
            .frame(width: 146, height: 76)
            .help("Drag photo directly into Finder, Slack, Discord, or Messages")
            .accessibilityLabel("Captured selfie image, draggable")
            .onDrag {
                if let url = camera.capturedTempURL {
                    return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: image)
                }
                return NSItemProvider(object: image)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    camera.isEnlarged = true
                }
            }

            // Action buttons row
            VStack(alignment: .leading, spacing: 6) {
                Text("Selfie Captured! 🎉")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    // Copy button (Cmd+C)
                    Button(action: {
                        camera.copyToClipboard()
                        withAnimation { copyFeedback = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copyFeedback = false }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                            Text(copyFeedback ? "Copied!" : "Copy")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(copyFeedback ? Color.green : Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(copyFeedback ? Color.green.opacity(0.25) : Color.white.opacity(isCopyHovered ? 0.22 : 0.14))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("c", modifiers: [.command])
                    .help("Copy to clipboard (Cmd+C)")
                    .accessibilityLabel("Copy photo to clipboard")
                    .onHover { isCopyHovered = $0 }

                    // Save to Downloads button (Cmd+S)
                    Button(action: {
                        _ = camera.saveToDownloads()
                        withAnimation { saveFeedback = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { saveFeedback = false }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: saveFeedback ? "checkmark" : "arrow.down.circle.fill")
                                .font(.system(size: 10))
                            Text(saveFeedback ? "Saved!" : "Save")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(saveFeedback ? Color.cyan : Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(saveFeedback ? Color.cyan.opacity(0.25) : Color.white.opacity(isSaveHovered ? 0.22 : 0.14))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Save to ~/Downloads (Cmd+S)")
                    .accessibilityLabel("Save photo to Downloads folder")
                    .onHover { isSaveHovered = $0 }

                    // Retake button (Esc)
                    Button(action: {
                        camera.retake()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Retake")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color.white.opacity(isRetakeHovered ? 0.9 : 0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.white.opacity(isRetakeHovered ? 0.16 : 0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Discard and retake (Esc)")
                    .accessibilityLabel("Retake photo")
                    .onHover { isRetakeHovered = $0 }
                }
            }
            .padding(.trailing, 10)

            Spacer()
        }
        .padding(.leading, 8)
    }

    // MARK: - Enlarged Captured Photo Preview
    private func enlargedCapturedView(image: NSImage) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 440, height: 155)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )

                // Top-right compact button
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        camera.isEnlarged = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 9, weight: .bold))
                        Text("Compact")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .padding(6)
                }
                .buttonStyle(.plain)
                .help("Click to shrink back to compact mirror")

                // Drag indicator badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 9))
                            Text("Drag out anywhere")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .padding(8)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: 440, height: 155)
            .onDrag {
                if let url = camera.capturedTempURL {
                    return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: image)
                }
                return NSItemProvider(object: image)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    camera.isEnlarged = false
                }
            }

            // Bottom actions bar
            HStack(spacing: 10) {
                Text("Selfie Ready!")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                // Copy
                Button(action: {
                    camera.copyToClipboard()
                    withAnimation { copyFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copyFeedback = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copyFeedback ? "Copied!" : "Copy (Cmd+C)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(copyFeedback ? Color.green : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(copyFeedback ? Color.green.opacity(0.25) : Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: [.command])

                // Save
                Button(action: {
                    _ = camera.saveToDownloads()
                    withAnimation { saveFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { saveFeedback = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: saveFeedback ? "checkmark" : "arrow.down.circle.fill")
                            .font(.system(size: 11))
                        Text(saveFeedback ? "Saved!" : "Save to Downloads")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(saveFeedback ? Color.cyan : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(saveFeedback ? Color.cyan.opacity(0.25) : Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: [.command])

                // Retake
                Button(action: {
                    camera.retake()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Retake")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .frame(width: 440)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 24))
                .foregroundStyle(.yellow)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("Camera Permission Required")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Allow camera access in macOS System Settings to use Quick Mirror.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.trailing, 12)
        }
    }
}
