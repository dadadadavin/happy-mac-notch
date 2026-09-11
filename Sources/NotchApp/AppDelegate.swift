import AppKit
import SwiftUI
import ApplicationServices

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NotchWindow?
    private let viewModel = NotchViewModel()

    private let maxWindowWidth: CGFloat = 860
    private let maxWindowHeight: CGFloat = 280

    public func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()
        setupNotchWindow()

        // Observe screen changes (connecting/disconnecting external monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func checkAccessibilityPermissions() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func setupNotchWindow() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first ?? NSScreen.main else { return }

        viewModel.updateGeometry(for: screen)

        // Center window at the top of the display
        let x = screen.frame.midX - (maxWindowWidth / 2)
        let y = screen.frame.maxY - maxWindowHeight
        let windowFrame = NSRect(x: x, y: y, width: maxWindowWidth, height: maxWindowHeight)

        let notchWindow = NotchWindow(contentRect: windowFrame)
        notchWindow.contentView = NSHostingView(
            rootView: NotchContainerView(vm: viewModel)
        )

        notchWindow.orderFrontRegardless()
        self.window = notchWindow
    }

    @objc private func screenParametersChanged() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first ?? NSScreen.main,
              let window = self.window else { return }

        viewModel.updateGeometry(for: screen)

        let x = screen.frame.midX - (maxWindowWidth / 2)
        let y = screen.frame.maxY - maxWindowHeight
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
