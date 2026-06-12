import Foundation
import Observation

@MainActor @Observable
final class UninstallerModel {
    private(set) var apps: [AppInfo] = []
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var leftovers: [LeftoverItem] = []
    private(set) var isLoadingLeftovers = false
    private(set) var isUninstalling = false
    private(set) var failures: [String] = []
    private(set) var lastUninstalled: String?
    var searchText = ""

    @ObservationIgnored private let history: HistoryStore

    init(history: HistoryStore) {
        self.history = history
    }

    var selectedApp: AppInfo? {
        didSet {
            guard selectedApp != oldValue else { return }
            leftovers = []
            lastUninstalled = nil
            failures = []
        }
    }

    var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedStandardContains(searchText) }
    }

    var leftoversSize: Int64 { leftovers.reduce(0) { $0 + $1.size } }

    func scanApps() async {
        guard !isScanning else { return }
        isScanning = true
        apps = await UninstallerService.scanApps()
        hasScanned = true
        isScanning = false
    }

    func loadLeftovers(for app: AppInfo) async {
        isLoadingLeftovers = true
        leftovers = await Task.detached(priority: .userInitiated) {
            UninstallerService.findLeftovers(for: app)
        }.value
        isLoadingLeftovers = false
    }

    func setLeftover(_ id: String, selected: Bool) {
        guard let index = leftovers.firstIndex(where: { $0.id == id }) else { return }
        leftovers[index].isSelected = selected
    }

    func uninstallSelected() async {
        guard let app = selectedApp, !isUninstalling else { return }
        isUninstalling = true

        var targets = [(id: app.id, url: app.url, size: app.size)]
        targets += leftovers.filter(\.isSelected).map { (id: $0.id, url: $0.url, size: $0.size) }

        let result = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(urls: targets, moveToTrash: true)
        }.value

        failures = result.failures
        history.record(
            source: "Uninstaller",
            files: targets.filter { result.cleanedIDs.contains($0.id) }
                .map { (path: $0.url.path, size: $0.size) },
            movedToTrash: true
        )
        if result.cleanedIDs.contains(app.id) {
            apps.removeAll { $0.id == app.id }
            lastUninstalled = app.name
            selectedApp = nil
            leftovers = []
        } else {
            leftovers.removeAll { result.cleanedIDs.contains($0.id) }
        }
        isUninstalling = false
    }
}
