import Foundation
import Observation

@MainActor @Observable
final class DuplicatesModel {
    private(set) var groups: [DuplicateGroup] = []
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var isCleaning = false
    private(set) var lastFreed: Int64 = 0
    private(set) var failures: [String] = []
    var minSize: Int64 = 1024 * 1024

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let history: HistoryStore

    init(settings: AppSettings, history: HistoryStore) {
        self.settings = settings
        self.history = history
    }

    static let sizeOptions: [(label: String, bytes: Int64)] = [
        ("1 MB", 1024 * 1024),
        ("10 MB", 10 * 1024 * 1024),
        ("100 MB", 100 * 1024 * 1024),
    ]

    var totalWasted: Int64 { groups.reduce(0) { $0 + $1.wastedSize } }
    var selectedSize: Int64 { groups.reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int { groups.reduce(0) { $0 + $1.selectedCount } }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        failures = []
        let threshold = minSize
        groups = await Task.detached(priority: .userInitiated) {
            await DuplicateScanner.scan(minSize: threshold)
        }.value
        hasScanned = true
        isScanning = false
    }

    func setFile(_ fileID: String, inGroup groupID: String, selected: Bool) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }),
              let fileIndex = groups[groupIndex].files.firstIndex(where: { $0.id == fileID })
        else { return }
        // Never allow selecting every copy in a group — one must survive.
        if selected, groups[groupIndex].selectedCount >= groups[groupIndex].files.count - 1 {
            return
        }
        groups[groupIndex].files[fileIndex].isSelected = selected
    }

    func keepNewestEverywhere() {
        for index in groups.indices {
            DuplicateScanner.selectAllButNewest(&groups[index])
        }
    }

    func keepOldestEverywhere() {
        for index in groups.indices {
            DuplicateScanner.selectAllButOldest(&groups[index])
        }
    }

    func removeSelected() async {
        guard !isCleaning, selectedCount > 0 else { return }
        isCleaning = true

        let targets = groups.flatMap { group in
            group.files.filter(\.isSelected).map { (id: $0.id, url: $0.url, size: group.fileSize) }
        }
        let toTrash = settings.moveToTrashDefault
        let result = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(urls: targets, moveToTrash: toTrash)
        }.value

        lastFreed = result.freed
        failures = result.failures
        history.record(
            source: "Duplicates",
            files: targets.filter { result.cleanedIDs.contains($0.id) }
                .map { (path: $0.url.path, size: $0.size) },
            movedToTrash: toTrash
        )
        for index in groups.indices {
            groups[index].files.removeAll { result.cleanedIDs.contains($0.id) }
        }
        groups.removeAll { $0.files.count < 2 }
        isCleaning = false
    }
}
