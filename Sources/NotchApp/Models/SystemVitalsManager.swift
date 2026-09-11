import Foundation
import IOKit
import IOKit.ps
import Darwin
import AppKit

@MainActor
public final class SystemVitalsManager: ObservableObject {
    public static let shared = SystemVitalsManager()

    @Published public var socTemperature: Double = 33.0
    @Published public var thermalStateString: String = "Cool"
    @Published public var batteryLevel: Int = 80
    @Published public var isCharging: Bool = false
    @Published public var cpuUsage: Int = 10
    @Published public var memoryUsage: Int = 50
    @Published public var storageFree: String = "--"
    @Published public var storageTotal: String = "--"
    @Published public var storageRatio: Double = 0.5
    @Published public var chipName: String = "Apple Silicon"
    @Published public var weatherTemp: String = ""
    @Published public var weatherCondition: String = ""

    private var previousCPULoad: host_cpu_load_info?
    private var lastWeatherFetchTime: TimeInterval = 0

    private init() {
        self.chipName = getChipBrand()
        refreshAll()
        fetchWeather()
    }

    public func refreshAll() {
        updateBattery()
        updateMemory()
        updateCPU()
        updateStorage()
        updateSocTemperature()
        if CACurrentMediaTime() - lastWeatherFetchTime > 900 {
            fetchWeather()
        }
    }

    private func getChipBrand() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let bytes = brand.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        let name = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return name.isEmpty ? "Apple Silicon" : name
    }

    public func updateBattery() {
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

    public func updateMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let pageSize = UInt64(getpagesize())
            let active = UInt64(stats.active_count) * UInt64(pageSize)
            let wired = UInt64(stats.wire_count) * UInt64(pageSize)
            let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
            let used = active + wired + compressed
            let total = ProcessInfo.processInfo.physicalMemory
            if total > 0 {
                self.memoryUsage = Int((Double(used) / Double(total)) * 100)
            }
        }
    }

    public func updateCPU() {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            if let prev = previousCPULoad {
                let user = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
                let sys = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
                let idle = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
                let nice = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)
                let total = user + sys + idle + nice
                if total > 0 {
                    let activePct = ((user + sys + nice) / total) * 100.0
                    self.cpuUsage = min(100, max(0, Int(activePct)))
                }
            }
            previousCPULoad = cpuLoad
        }
    }

    public func updateStorage() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let free = attrs[.systemFreeSize] as? Int64,
              let total = attrs[.systemSize] as? Int64, total > 0 else {
            return
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        self.storageFree = formatter.string(fromByteCount: free)
        self.storageTotal = formatter.string(fromByteCount: total)
        self.storageRatio = max(0.0, min(1.0, Double(total - free) / Double(total)))
    }

    public func updateSocTemperature() {
        typealias IOHIDEventSystemClientCreateFunc = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias IOHIDEventSystemClientSetMatchingFunc = @convention(c) (AnyObject, CFDictionary) -> Void
        typealias IOHIDEventSystemClientCopyServicesFunc = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
        typealias IOHIDServiceClientCopyEventFunc = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
        typealias IOHIDEventGetFloatValueFunc = @convention(c) (AnyObject, Int32) -> Double

        let handle = dlopen(nil, RTLD_NOW)
        guard let s1 = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let s2 = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let s3 = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let s4 = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let s5 = dlsym(handle, "IOHIDEventGetFloatValue") else {
            return
        }

        let clientCreate = unsafeBitCast(s1, to: IOHIDEventSystemClientCreateFunc.self)
        let setMatching = unsafeBitCast(s2, to: IOHIDEventSystemClientSetMatchingFunc.self)
        let copyServices = unsafeBitCast(s3, to: IOHIDEventSystemClientCopyServicesFunc.self)
        let copyEvent = unsafeBitCast(s4, to: IOHIDServiceClientCopyEventFunc.self)
        let getFloatValue = unsafeBitCast(s5, to: IOHIDEventGetFloatValueFunc.self)

        guard let client = clientCreate(kCFAllocatorDefault)?.takeRetainedValue() else { return }
        let dict: [String: Any] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
        setMatching(client, dict as CFDictionary)
        guard let services = copyServices(client)?.takeRetainedValue() as? [AnyObject] else { return }

        var temps: [Double] = []
        for service in services {
            if let event = copyEvent(service, 15, 0, 0)?.takeRetainedValue() {
                let temp = getFloatValue(event, 15 << 16)
                if temp > 18 && temp < 110 {
                    temps.append(temp)
                }
            }
        }
        if !temps.isEmpty {
            let avg = temps.reduce(0, +) / Double(temps.count)
            self.socTemperature = avg
            if avg < 45 {
                self.thermalStateString = "Cool"
            } else if avg < 68 {
                self.thermalStateString = "Nominal"
            } else if avg < 85 {
                self.thermalStateString = "Warm"
            } else {
                self.thermalStateString = "Hot"
            }
        }
    }

    public func fetchWeather() {
        guard let url = URL(string: "https://wttr.in/?format=%t+%C") else { return }
        lastWeatherFetchTime = CACurrentMediaTime()
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            let parts = text.components(separatedBy: " ")
            let temp = parts.first ?? ""
            let condition = parts.dropFirst().joined(separator: " ")
            DispatchQueue.main.async {
                self?.weatherTemp = temp
                self?.weatherCondition = condition
            }
        }.resume()
    }
}
