import AppKit
import Combine
import SwiftUI
import IOKit.ps
import Darwin

public enum NotchState: Equatable {
    case closed
    case compact
    case open
}

public enum ActiveTab: String, CaseIterable, Identifiable {
    case music = "Music"
    case dropZone = "Drop Shelf"
    case mirror = "Mirror"
    case stats = "Stats"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .music: return "music.note"
        case .dropZone: return "tray.and.arrow.down.fill"
        case .mirror: return "camera.fill"
        case .stats: return "gauge.with.needle.fill"
        }
    }
}

@MainActor
public final class NotchViewModel: ObservableObject {
    @Published public var state: NotchState = .closed {
        didSet {
            if state == .open && activeTab == .mirror {
                CameraManager.shared.startSession()
            } else if state != .open {
                CameraManager.shared.stopSession()
            }
        }
    }
    @Published public var isHovering: Bool = false
    @Published public var activeTab: ActiveTab = .music {
        didSet {
            if activeTab == .mirror && state == .open {
                CameraManager.shared.startSession()
            } else {
                CameraManager.shared.stopSession()
            }
        }
    }
    @Published public var geometry: NotchGeometry

    // System stats
    @Published public var batteryLevel: Int = 88
    @Published public var isCharging: Bool = false
    @Published public var cpuUsage: Int = 12
    @Published public var memoryUsage: Int = 45

    // Dropped files
    @Published public var droppedFiles: [URL] = []

    public func addDroppedFile(_ url: URL) {
        if !droppedFiles.contains(url) {
            droppedFiles.append(url)
        }
    }

    public func removeDroppedFile(_ url: URL) {
        droppedFiles.removeAll { $0 == url }
    }

    public func clearDroppedFiles() {
        droppedFiles.removeAll()
    }

    private var hoverTask: Task<Void, Never>?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    // Performance: Cached screen geometry to avoid continuous AppKit IPC queries
    private var cachedScreenTop: CGFloat = 900
    private var cachedScreenMidX: CGFloat = 720
    private var lastProximityCheckTime: Double = 0

    public init() {
        let initialScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first ?? NSScreen.main
        self.geometry = NotchGeometry.current(for: initialScreen)
        if let s = initialScreen {
            self.cachedScreenTop = s.frame.maxY
            self.cachedScreenMidX = s.frame.midX
        }
        self.updateBatteryStatus()
        self.startMouseProximityMonitoring()
    }

    public func updateGeometry(for screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first ?? NSScreen.main
        self.geometry = NotchGeometry.current(for: targetScreen)
        if let s = targetScreen {
            self.cachedScreenTop = s.frame.maxY
            self.cachedScreenMidX = s.frame.midX
        }
    }

    // Dynamic dimensions
    public var currentWidth: CGFloat {
        switch state {
        case .closed:
            return geometry.physicalSize.width
        case .compact:
            return geometry.physicalSize.width + 120
        case .open:
            return 615
        }
    }

    public var currentHeight: CGFloat {
        switch state {
        case .closed:
            return geometry.physicalSize.height
        case .compact:
            return geometry.physicalSize.height
        case .open:
            return geometry.physicalSize.height + 122
        }
    }

    public var topRadius: CGFloat {
        switch state {
        case .closed: return 6
        case .compact: return 8
        case .open: return 12
        }
    }

    public var bottomRadius: CGFloat {
        switch state {
        case .closed: return 14
        case .compact: return 16
        case .open: return 24
        }
    }

    // MARK: - Ultra-Optimized Mouse Tracking (Zero allocations when cursor is away)
    private func startMouseProximityMonitoring() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.throttledProximityCheck()
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.throttledProximityCheck()
            return event
        }
    }

    private func throttledProximityCheck() {
        let now = CACurrentMediaTime()
        // Rate limit checks to ~40Hz (25ms) for ultra-responsive tracking
        guard now - lastProximityCheckTime >= 0.025 else { return }
        lastProximityCheckTime = now

        let mouseLoc = NSEvent.mouseLocation
        let distFromTop = cachedScreenTop - mouseLoc.y
        let distX = abs(mouseLoc.x - cachedScreenMidX)

        if state == .open {
            // Immediate collapse: as soon as cursor leaves the 615pt card boundaries (307.5pt half-width)
            // or drops below the card bottom (currentHeight + 6pt)
            let isOutsideCard = (distX > 315) || (distFromTop > (currentHeight + 6)) || (distFromTop < -10)
            if isOutsideCard {
                DispatchQueue.main.async { [weak self] in
                    self?.handleHover(false)
                }
            }
            return
        }

        // Fast early exit: if closed and cursor is not touching the top edge (distFromTop > 2.0 or < -3.0)
        // or is horizontally outside the physical notch cutout (cannot be opened from side)
        let notchHalfWidth = geometry.physicalSize.width / 2.0
        if state == .closed {
            let isAtTopEdge = (distFromTop <= 2.0 && distFromTop >= -3.0)
            let isWithinNotchX = (distX <= (notchHalfWidth - 3.0))
            if !isAtTopEdge || !isWithinNotchX {
                if hoverTask != nil && !isHovering {
                    DispatchQueue.main.async { [weak self] in
                        self?.cancelHoverTask()
                    }
                }
                return
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.checkMouseProximity(at: mouseLoc, distFromTop: distFromTop, distX: distX)
        }
    }

    private func checkMouseProximity(at mouseLoc: CGPoint, distFromTop: CGFloat, distX: CGFloat) {
        if state == .closed {
            // STRICT PHYSICAL UP END TOUCH ONLY:
            // 1. Must literally touch the physical top edge (distFromTop <= 2.0pt)
            // 2. Must be strictly within the notch cutout horizontally (cannot be opened from side!)
            let notchHalfWidth = geometry.physicalSize.width / 2.0
            let isTouchingUpEnd = (distFromTop <= 2.0 && distFromTop >= -3.0)
            let isWithinNotchCutout = (distX <= (notchHalfWidth - 3.0))

            if isTouchingUpEnd && isWithinNotchCutout {
                // Not overly sensitive: require a deliberate dwell (140ms) at the top edge.
                // Prevents fast swipes across the screen from triggering the notch.
                if hoverTask == nil && state == .closed {
                    hoverTask = Task {
                        try? await Task.sleep(for: .milliseconds(140))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            guard self.state == .closed else { return }
                            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78)) {
                                self.state = .open
                                self.isHovering = true
                            }
                        }
                    }
                }
            } else {
                cancelHoverTask()
            }
        } else if state == .open {
            let isFarAway = (distX > 315) || (distFromTop > (currentHeight + 6)) || (distFromTop < -10)
            if isFarAway {
                handleHover(false)
            }
        }
    }

    public func cancelHoverTask() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    // Hover management: instant pop when touching edge, instant pop back in when leaving
    public func handleHover(_ hovering: Bool) {
        cancelHoverTask()

        if hovering {
            isHovering = true
            guard state != .open else { return }

            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78)) {
                self.state = .open
            }
        } else {
            isHovering = false

            // Instant pop back in (zero delay!)
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.84)) {
                self.state = .closed
            }
        }
    }

    public func toggleOpen() {
        cancelHoverTask()
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.8)) {
            state = (state == .open) ? .closed : .open
            isHovering = (state == .open)
        }
    }

    // MARK: - Native IOKit Battery (0 processes, 0 disk I/O, runs in microseconds)
    public func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let current = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                self.batteryLevel = Int((Double(current) / Double(max)) * 100)
                self.isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                break
            }
        }
    }
}
