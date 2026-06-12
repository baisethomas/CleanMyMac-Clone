import Foundation
import Observation

@MainActor @Observable
final class MaintenanceModel {
    struct TaskOutcome: Sendable {
        let succeeded: Bool
        let message: String
    }

    private(set) var runningTaskIDs: Set<String> = []
    private(set) var outcomes: [String: TaskOutcome] = [:]

    let tasks = MaintenanceService.tasks

    func run(_ task: MaintenanceTask) async {
        guard !runningTaskIDs.contains(task.id) else { return }
        runningTaskIDs.insert(task.id)
        outcomes[task.id] = nil

        let result = await MaintenanceService.run(task)

        let message: String
        if result.succeeded {
            message = result.output.isEmpty ? "Completed" : result.output
        } else if result.output.localizedStandardContains("User canceled") {
            message = "Cancelled"
        } else {
            message = result.output.isEmpty ? "Failed" : result.output
        }
        outcomes[task.id] = TaskOutcome(succeeded: result.succeeded, message: message)
        runningTaskIDs.remove(task.id)
    }
}
