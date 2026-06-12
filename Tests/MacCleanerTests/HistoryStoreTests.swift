import Testing
import Foundation
@testable import MacCleaner

@MainActor
struct HistoryStoreTests {
    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("history-\(UUID().uuidString).json")
    }

    @Test func recordsAndTotalsEvents() {
        let url = tempStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = HistoryStore(fileURL: url)
        store.record(
            source: "System Junk",
            files: [(path: "/tmp/a", size: 100), (path: "/tmp/b", size: 150)],
            movedToTrash: true
        )
        store.record(source: "Privacy", files: [(path: "/tmp/c", size: 50)], movedToTrash: false)

        #expect(store.events.count == 2)
        #expect(store.totalCleaned == 300)
        // Newest first.
        #expect(store.events.first?.source == "Privacy")
    }

    @Test func persistsAcrossInstances() {
        let url = tempStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = HistoryStore(fileURL: url)
        store.record(source: "Duplicates", files: [(path: "/tmp/d", size: 4096)], movedToTrash: true)

        let reloaded = HistoryStore(fileURL: url)
        #expect(reloaded.events.count == 1)
        #expect(reloaded.events.first?.source == "Duplicates")
        #expect(reloaded.totalCleaned == 4096)
    }

    @Test func emptyRecordIsIgnored() {
        let url = tempStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = HistoryStore(fileURL: url)
        store.record(source: "System Junk", files: [], movedToTrash: true)
        #expect(store.events.isEmpty)
    }
}
