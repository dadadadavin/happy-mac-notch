import AppKit
import Foundation

public struct NotchGeometry {
    public let hasNotch: Bool
    public let physicalSize: CGSize
    public let screenFrame: CGRect
    public let menuBarHeight: CGFloat

    public static func current(for screen: NSScreen? = NSScreen.main) -> NotchGeometry {
        guard let screen = screen else {
            return NotchGeometry(
                hasNotch: false,
                physicalSize: CGSize(width: 200, height: 32),
                screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
                menuBarHeight: 28
            )
        }

        let screenFrame = screen.frame
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY

        // Check if the screen has physical notch cutouts
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            let notchWidth = screenFrame.width - leftArea.width - rightArea.width
            let notchHeight = screen.safeAreaInsets.top
            return NotchGeometry(
                hasNotch: true,
                physicalSize: CGSize(width: notchWidth, height: notchHeight),
                screenFrame: screenFrame,
                menuBarHeight: menuBarHeight
            )
        } else {
            // Non-notch Mac or external monitor fallback
            let fallbackWidth: CGFloat = 220
            let fallbackHeight: CGFloat = max(32, menuBarHeight)
            return NotchGeometry(
                hasNotch: false,
                physicalSize: CGSize(width: fallbackWidth, height: fallbackHeight),
                screenFrame: screenFrame,
                menuBarHeight: menuBarHeight
            )
        }
    }

    /// Frame for placing the overlay window centered at the top of the display
    public func windowFrame(for width: CGFloat, height: CGFloat) -> NSRect {
        let x = screenFrame.midX - (width / 2)
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
