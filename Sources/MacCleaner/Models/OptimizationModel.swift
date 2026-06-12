import Foundation
import Observation

@MainActor @Observable
final class OptimizationModel {
    enum ProcessSort: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
    }

    private(set) var processes: [RunningProcessInfo] = []
    private(set) var agents: [LaunchAgent] = []
    private(set) var agentError: String?
    private(set) var busyAgentIDs: Set<String> = []
    var processSort: ProcessSort = .cpu

    var sortedProcesses: [RunningProcessInfo] {
        let sorted = switch processSort {
        case .cpu: processes.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory: processes.sorted { $0.memoryBytes > $1.memoryBytes }
        }
        return Array(sorted.prefix(15))
    }

    /// Refreshes the process list every few seconds until cancelled.
    func monitorProcesses() async {
        while !Task.isCancelled {
            processes = await ProcessService.topProcesses()
            try? await Task.sleep(for: .seconds(3))
        }
    }

    func quit(_ process: RunningProcessInfo) async {
        _ = ProcessService.quit(pid: process.id)
        try? await Task.sleep(for: .milliseconds(500))
        processes = await ProcessService.topProcesses()
    }

    func loadAgents() async {
        agents = await Task.detached { LaunchAgentService.list() }.value
    }

    func setAgent(_ agent: LaunchAgent, enabled: Bool) async {
        busyAgentIDs.insert(agent.id)
        agentError = await LaunchAgentService.setEnabled(agent, enabled: enabled)
        await loadAgents()
        busyAgentIDs.remove(agent.id)
    }
}
