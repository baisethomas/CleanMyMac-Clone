import Foundation
import Observation

@MainActor @Observable
final class StatsModel {
    private(set) var disk: DiskStats?
    private(set) var memory: MemoryStats?
    private(set) var cpuPercent: Double = 0

    func refresh() {
        disk = SystemStats.disk()
        memory = SystemStats.memory()
        cpuPercent = SystemStats.cpuLoadPercent()
    }

    /// Refreshes every few seconds until the task is cancelled.
    func monitor() async {
        refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            refresh()
        }
    }
}
