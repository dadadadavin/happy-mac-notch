import SwiftUI
import AppKit

public struct SystemStatsWidget: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var vitals = SystemVitalsManager.shared
    @State private var isLockHovered: Bool = false
    @State private var isQuitHovered: Bool = false

    public init(vm: NotchViewModel) {
        self.vm = vm
    }

    public var body: some View {
        HStack(spacing: 8) {
            // CARD 1: Battery & Power Tile
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: CGFloat(vitals.batteryLevel) / 100.0)
                        .stroke(
                            vitals.isCharging
                                ? Color.green
                                : (vitals.batteryLevel > 20 ? Color.green : Color.orange),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 40)

                    if vitals.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.yellow)
                    } else {
                        Text("\(vitals.batteryLevel)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(vitals.isCharging ? "Charging" : "\(vitals.batteryLevel)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(vitals.isCharging ? "Power" : "Battery")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 108, height: 76)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )

            // CARD 2: CPU, Memory & Hardware Temperature
            VStack(alignment: .leading, spacing: 5) {
                // CPU Row
                HStack(spacing: 4) {
                    Text("CPU")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                            Capsule().fill(Color.cyan).frame(width: max(3, geo.size.width * (CGFloat(vitals.cpuUsage) / 100.0)), height: 3)
                        }
                    }
                    .frame(height: 3)
                    Text("\(vitals.cpuUsage)%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Memory Row
                HStack(spacing: 4) {
                    Text("RAM")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.indigo)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                            Capsule().fill(Color.indigo).frame(width: max(3, geo.size.width * (CGFloat(vitals.memoryUsage) / 100.0)), height: 3)
                        }
                    }
                    .frame(height: 3)
                    Text("\(vitals.memoryUsage)%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }

                // SOC Temperature Row
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 9))
                        .foregroundStyle(tempColor)

                    Text(String(format: "%.0f°C", vitals.socTemperature))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(vitals.thermalStateString)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(tempColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(tempColor.opacity(0.16)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 175, height: 76)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )

            // CARD 3: Storage & Ambient Weather
            VStack(alignment: .leading, spacing: 6) {
                // Disk Storage Row
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.purple)
                        Text("SSD Free")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(vitals.storageFree)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                            Capsule()
                                .fill(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(3, geo.size.width * CGFloat(vitals.storageRatio)), height: 3)
                        }
                    }
                    .frame(height: 3)
                }

                // Chip & Weather Row
                HStack(spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 9))
                        Text(vitals.chipName)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    if !vitals.weatherTemp.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.yellow)
                            Text(vitals.weatherTemp)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 175, height: 76)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )

            // CARD 4: Quick Actions (Lock & Quit)
            VStack(spacing: 6) {
                // Lock Button
                Button(action: {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
                    task.arguments = ["displaysleepnow"]
                    try? task.run()
                }) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isLockHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) { isLockHovered = hovering }
                }

                // Quit Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(width: 48, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isQuitHovered ? Color.red.opacity(0.22) : Color.red.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) { isQuitHovered = hovering }
                }
            }
            .frame(width: 48, height: 76)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .task {
            // Background refresh loop strictly while widget is mounted on screen
            while !Task.isCancelled {
                vitals.refreshAll()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private var tempColor: Color {
        if vitals.socTemperature < 45 {
            return Color.green
        } else if vitals.socTemperature < 68 {
            return Color.cyan
        } else if vitals.socTemperature < 82 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}
