import Foundation
import Observation

@MainActor @Observable
final class JunkModel {
    enum Phase {
        case idle, scanning, reviewing, cleaning, finished
    }

    private(set) var phase: Phase = .idle
    private(set) var categories: [JunkCategory] = []
    private(set) var currentScanTarget = ""
    private(set) var scanProgress: Double = 0
    private(set) var lastFreed: Int64 = 0
    private(set) var lastScanDate: Date?
    private(set) var failures: [String] = []
    var moveToTrash: Bool

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let history: HistoryStore

    init(settings: AppSettings, history: HistoryStore) {
        self.settings = settings
        self.history = history
        self.moveToTrash = settings.moveToTrashDefault
    }

    var totalFound: Int64 { categories.reduce(0) { $0 + $1.totalSize } }
    var selectedSize: Int64 { categories.reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int { categories.reduce(0) { $0 + $1.selectedCount } }

    func scan() async {
        guard phase != .scanning, phase != .cleaning else { return }
        phase = .scanning
        categories = []
        scanProgress = 0
        failures = []

        let options = settings.scanOptions
        let specs = JunkScanner.specs
        var inFlight = Set(specs.map(\.name))
        currentScanTarget = specs.first?.name ?? ""
        var completed = 0

        await withTaskGroup(of: JunkCategory.self) { group in
            for spec in specs {
                group.addTask {
                    await JunkScanner.scan(spec, options: options)
                }
            }
            for await category in group {
                completed += 1
                inFlight.remove(category.name)
                scanProgress = Double(completed) / Double(specs.count)
                currentScanTarget = inFlight.first ?? ""
                if !category.items.isEmpty {
                    categories.append(category)
                }
            }
        }

        categories.sort { $0.totalSize > $1.totalSize }
        currentScanTarget = ""
        lastScanDate = .now
        phase = .reviewing
    }

    func clean() async {
        guard phase == .reviewing, selectedCount > 0 else { return }
        phase = .cleaning

        let targets = categories.flatMap { category in
            category.items.filter(\.isSelected).map { (id: $0.id, url: $0.url, size: $0.size) }
        }
        let toTrash = moveToTrash
        let result = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(urls: targets, moveToTrash: toTrash)
        }.value

        lastFreed = result.freed
        failures = result.failures
        history.record(
            source: "System Junk",
            files: targets.filter { result.cleanedIDs.contains($0.id) }
                .map { (path: $0.url.path, size: $0.size) },
            movedToTrash: toTrash
        )
        for index in categories.indices {
            categories[index].items.removeAll { result.cleanedIDs.contains($0.id) }
        }
        categories.removeAll { $0.items.isEmpty }
        phase = .finished
    }

    func reset() {
        phase = .idle
        categories = []
        lastFreed = 0
        failures = []
    }

    func setItem(_ itemID: String, inCategory categoryID: String, selected: Bool) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }),
              let itemIndex = categories[categoryIndex].items.firstIndex(where: { $0.id == itemID })
        else { return }
        categories[categoryIndex].items[itemIndex].isSelected = selected
    }

    func setCategory(_ categoryID: String, selected: Bool) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        for itemIndex in categories[categoryIndex].items.indices {
            categories[categoryIndex].items[itemIndex].isSelected = selected
        }
    }
}
