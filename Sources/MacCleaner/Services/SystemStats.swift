import Foundation

enum SystemStats {
    static func disk() -> DiskStats? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]) else { return nil }
        return DiskStats(
            total: Int64(values.volumeTotalCapacity ?? 0),
            free: values.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }

    static func memory() -> MemoryStats {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return MemoryStats(total: total, used: 0) }

        let used = (Int64(stats.active_count)
            + Int64(stats.wire_count)
            + Int64(stats.compressor_page_count)) * Int64(pageSize)
        return MemoryStats(total: total, used: used)
    }

    /// 1-minute load average as a percentage of available cores.
    static func cpuLoadPercent() -> Double {
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)
        let cores = Double(ProcessInfo.processInfo.activeProcessorCount)
        guard cores > 0 else { return 0 }
        return min(loads[0] / cores * 100, 100)
    }
}
