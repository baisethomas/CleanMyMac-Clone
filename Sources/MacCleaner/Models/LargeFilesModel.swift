import Foundation
import Observation

@MainActor @Observable
final class LargeFilesModel {
    private(set) var files: [LargeFile] = []
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var lastFreed: Int64 = 0
    private(set) var failures: [String] = []
    var selection: Set<String> = []
    var minSize: Int64 = 100 * 1024 * 1024

    @ObservationIgnored private let history: HistoryStore

    init(history: HistoryStore) {
        self.history = history
    }

    static let sizeOptions: [(label: String, bytes: Int64)] = [
        ("50 MB", 50 * 1024 * 1024),
        ("100 MB", 100 * 1024 * 1024),
        ("500 MB", 500 * 1024 * 1024),
        ("1 GB", 1024 * 1024 * 1024),
    ]

    var selectedSize: Int64 {
        files.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        selection = []
        let threshold = minSize
        files = await Task.detached(priority: .userInitiated) {
            LargeFilesScanner.scan(minSize: threshold)
        }.value
        hasScanned = true
        isScanning = false
    }

    func removeSelected() async {
        let targets = files
            .filter { selection.contains($0.id) }
            .map { (id: $0.id, url: $0.url, size: $0.size) }
        guard !targets.isEmpty else { return }

        let result = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(urls: targets, moveToTrash: true)
        }.value
        lastFreed = result.freed
        failures = result.failures
        history.record(
            source: "Large & Old Files",
            files: targets.filter { result.cleanedIDs.contains($0.id) }
                .map { (path: $0.url.path, size: $0.size) },
            movedToTrash: true
        )
        files.removeAll { result.cleanedIDs.contains($0.id) }
        selection = []
    }
}
