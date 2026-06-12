import AppKit

struct RunningProcessInfo: Identifiable, Hashable, Sendable {
    let id: Int32
    let name: String
    let cpuPercent: Double
    let memoryBytes: Int64
}

enum ProcessService {
    /// Top processes by CPU via `ps` (rss is in KB).
    static func topProcesses(limit: Int = 20) async -> [RunningProcessInfo] {
        let result = await Shell.run("/bin/ps", ["-Aceo", "pid=,pcpu=,rss=,comm=", "-r"])
        guard result.succeeded else { return [] }

        var processes: [RunningProcessInfo] = []
        for line in result.output.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Int64(parts[2]) else { continue }
            processes.append(RunningProcessInfo(
                id: pid,
                name: parts[3...].joined(separator: " "),
                cpuPercent: cpu,
                memoryBytes: rssKB * 1024
            ))
            if processes.count >= limit * 3 { break }
        }
        return Array(processes.prefix(limit * 3))
    }

    /// Asks the process to quit. GUI apps get a regular terminate; everything
    /// else gets SIGTERM.
    @MainActor
    static func quit(pid: Int32) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.terminate()
        }
        return kill(pid, SIGTERM) == 0
    }
}
