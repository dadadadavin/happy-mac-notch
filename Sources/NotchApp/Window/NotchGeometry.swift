import AppKit
import CoreGraphics
import Foundation

public struct NotchGeometry: Sendable {
    public let hasNotch: Bool
    public let physicalSize: CGSize
    public let screenFrame: CGRect
    public let menuBarHeight: CGFloat

    // Cache physical notch sizes by CGDirectDisplayID so fullscreen spaces (where safeAreaInsets.top becomes 0)
    // never lose the true hardware notch dimensions.
    @MainActor
    private static var cachedNotchSizes: [CGDirectDisplayID: CGSize] = [:]

    @MainActor
    public static func targetScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        if let builtin = NSScreen.screens.first(where: { screen in
            guard let id = displayID(for: screen) else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }) {
            return builtin
        }
        return NSScreen.screens.first ?? NSScreen.main
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    @MainActor
    public static func current(for screen: NSScreen? = nil) -> NotchGeometry {
        guard let screen = screen ?? targetScreen() else {
            return NotchGeometry(
                hasNotch: false,
                physicalSize: CGSize(width: 200, height: 32),
                screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
                menuBarHeight: 28
            )
        }

        let screenFrame = screen.frame
        let rawMenuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let menuBarHeight = rawMenuBarHeight > 0 ? rawMenuBarHeight : 32
        let dispID = displayID(for: screen)

        // Check if the screen currently reports physical notch cutouts
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            let notchWidth = screenFrame.width - leftArea.width - rightArea.width
            let notchHeight = screen.safeAreaInsets.top
            let size = CGSize(width: notchWidth, height: notchHeight)
            if let dispID {
                cachedNotchSizes[dispID] = size
            }
            return NotchGeometry(
                hasNotch: true,
                physicalSize: size,
                screenFrame: screenFrame,
                menuBarHeight: max(menuBarHeight, notchHeight)
            )
        }

        // If in a fullscreen space on a notched display, safeAreaInsets.top may report 0; use cached hardware size
        if let dispID, let cachedSize = cachedNotchSizes[dispID] {
            return NotchGeometry(
                hasNotch: true,
                physicalSize: cachedSize,
                screenFrame: screenFrame,
                menuBarHeight: max(menuBarHeight, cachedSize.height)
            )
        }

        // Built-in MacBook display fallback if launched while already inside a fullscreen app
        if let dispID, CGDisplayIsBuiltin(dispID) != 0 {
            let fallbackHeight: CGFloat = max(32, rawMenuBarHeight > 0 ? rawMenuBarHeight : 32)
            let fallbackSize = CGSize(width: 205, height: fallbackHeight)
            return NotchGeometry(
                hasNotch: true,
                physicalSize: fallbackSize,
                screenFrame: screenFrame,
                menuBarHeight: fallbackHeight
            )
        }

        // Non-notch Mac or external monitor fallback
        let fallbackWidth: CGFloat = 220
        let fallbackHeight: CGFloat = max(32, menuBarHeight)
        return NotchGeometry(
            hasNotch: false,
            physicalSize: CGSize(width: fallbackWidth, height: fallbackHeight),
            screenFrame: screenFrame,
            menuBarHeight: fallbackHeight
        )
    }

    /// Frame for placing the overlay window centered at the top of the display
    public func windowFrame(for width: CGFloat, height: CGFloat) -> NSRect {
        let x = screenFrame.midX - (width / 2)
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
