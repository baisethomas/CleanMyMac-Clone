import Foundation
import Observation

struct CleanedFileRecord: Codable, Hashable, Sendable {
    let path: String
    let size: Int64
}

struct CleanEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let source: String
    let totalSize: Int64
    let movedToTrash: Bool
    var files: [CleanedFileRecord]
    var undone: Bool
}

struct RestoreResult: Sendable {
    let restoredCount: Int
    let failures: [String]
}

@MainActor @Observable
final class HistoryStore {
    private(set) var events: [CleanEvent] = []
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MacCleaner")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("history.json")
        }
        load()
    }

    var totalCleaned: Int64 { events.reduce(0) { $0 + $1.totalSize } }

    func record(source: String, files: [(path: String, size: Int64)], movedToTrash: Bool) {
        guard !files.isEmpty else { return }
        let event = CleanEvent(
            id: UUID(),
            date: .now,
            source: source,
            totalSize: files.reduce(0) { $0 + $1.size },
            movedToTrash: movedToTrash,
            files: files.map { CleanedFileRecord(path: $0.path, size: $0.size) },
            undone: false
        )
        events.insert(event, at: 0)
        save()
    }

    /// Moves the event's files back out of the Trash to their original locations.
    /// Best effort: returns per-file failure messages.
    func undo(_ event: CleanEvent) async -> RestoreResult {
        guard let index = events.firstIndex(where: { $0.id == event.id }),
              event.movedToTrash, !event.undone else {
            return RestoreResult(restoredCount: 0, failures: ["This cleanup can't be undone."])
        }
        let files = event.files
        let result = await Task.detached(priority: .userInitiated) {
            TrashRestorer.restore(files)
        }.value
        if result.restoredCount > 0 {
            events[index].undone = true
            save()
        }
        return result
    }

    func clearHistory() {
        events = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CleanEvent].self, from: data) else { return }
        events = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

enum TrashRestorer {
    static func restore(_ files: [CleanedFileRecord]) -> RestoreResult {
        let fm = FileManager.default
        let trash = fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        var restored = 0
        var failures: [String] = []

        for record in files {
            let original = URL(fileURLWithPath: record.path)
            let name = original.lastPathComponent
            let inTrash = trash.appendingPathComponent(name)
            guard fm.fileExists(atPath: inTrash.path) else {
                failures.append("\(name): no longer in Trash")
                continue
            }
            guard !fm.fileExists(atPath: original.path) else {
                failures.append("\(name): original location is occupied")
                continue
            }
            do {
                try fm.createDirectory(
                    at: original.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fm.moveItem(at: inTrash, to: original)
                restored += 1
            } catch {
                failures.append("\(name): \(error.localizedDescription)")
            }
        }
        return RestoreResult(restoredCount: restored, failures: failures)
    }
}
