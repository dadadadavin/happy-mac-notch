import AppKit

public final class NotchWindow: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.isOpaque = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isMovable = false
        self.hasShadow = false
        self.isReleasedWhenClosed = false

        // Always use dark appearance to blend seamlessly with hardware notch
        self.appearance = NSAppearance(named: .darkAqua)

        // Float above the menu bar, fullscreen applications, and mission control
        self.level = .mainMenu + 3
        self.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        // Register for file drag and drop so window server dispatches drops to this panel
        self.registerForDraggedTypes([
            .fileURL,
            .URL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.item")
        ])
    }

    public override var canBecomeKey: Bool {
        false
    }

    public override var canBecomeMain: Bool {
        false
    }
}
