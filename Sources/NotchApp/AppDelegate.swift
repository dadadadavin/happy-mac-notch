import AppKit
import Combine
import SwiftUI
import ApplicationServices

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NotchWindow?
    private let viewModel = NotchViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let maxWindowWidth: CGFloat = 860
    private let maxWindowHeight: CGFloat = 380

    public func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()
        setupNotchWindow()
        setupObservers()
    }

    private func checkAccessibilityPermissions() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func setupNotchWindow() {
        guard let screen = NotchGeometry.targetScreen() else { return }

        viewModel.updateGeometry(for: screen)

        let x = screen.frame.midX - (maxWindowWidth / 2)
        let y = screen.frame.maxY - maxWindowHeight
        let windowFrame = NSRect(x: x, y: y, width: maxWindowWidth, height: maxWindowHeight)

        let notchWindow = NotchWindow(contentRect: windowFrame)

        let hostingView = NSHostingView(rootView: NotchContainerView(vm: viewModel))
        // Critical: forbid NSHostingView from mutating the NSWindow frame size when SwiftUI content expands
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(x: 0, y: 0, width: maxWindowWidth, height: maxWindowHeight)
        hostingView.autoresizingMask = [.width, .height]

        notchWindow.contentView = hostingView
        notchWindow.pinToTop(of: screen, width: maxWindowWidth, height: maxWindowHeight)
        notchWindow.orderFrontRegardless()
        self.window = notchWindow
    }

    private func setupObservers() {
        // Observe screen resolution / monitor topology changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenOrSpaceChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Observe macOS Fullscreen and Mission Control space transitions
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenOrSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // Ensure window stays pinned whenever notch state or mirror enlargement toggles
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncWindowFrame()
            }
            .store(in: &cancellables)

        CameraManager.shared.$isEnlarged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncWindowFrame()
            }
            .store(in: &cancellables)
    }

    @objc private func handleScreenOrSpaceChange() {
        syncWindowFrame()
        // Re-sync after macOS finishes fullscreen/space transition animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.syncWindowFrame()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.syncWindowFrame()
        }
    }

    private func syncWindowFrame() {
        guard let screen = NotchGeometry.targetScreen(),
              let window = self.window else { return }

        viewModel.updateGeometry(for: screen)
        window.pinToTop(of: screen, width: maxWindowWidth, height: maxWindowHeight)
    }
}
