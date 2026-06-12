import AppKit
import Observation

@MainActor @Observable
final class PrivacyModel {
    private(set) var browsers: [BrowserData] = []
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var isCleaning = false
    private(set) var lastFreed: Int64 = 0
    private(set) var failures: [String] = []

    @ObservationIgnored private let history: HistoryStore

    init(history: HistoryStore) {
        self.history = history
    }

    /// Size of selected items in browsers that are safe to clean (not running).
    var cleanableSelectedSize: Int64 {
        browsers.filter { !$0.isRunning }.reduce(0) { $0 + $1.selectedSize }
    }

    var cleanableSelectedCount: Int {
        browsers.filter { !$0.isRunning }.reduce(0) { $0 + $1.selectedCount }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        failures = []
        var scanned = await Task.detached(priority: .userInitiated) {
            await PrivacyScanner.scan()
        }.value
        for index in scanned.indices {
            scanned[index].appPath = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: scanned[index].bundleID)?.path
            scanned[index].isRunning = isRunning(scanned[index].bundleID)
        }
        browsers = scanned
        hasScanned = true
        isScanning = false
    }

    func refreshRunningStates() {
        for index in browsers.indices {
            browsers[index].isRunning = isRunning(browsers[index].bundleID)
        }
    }

    func quitBrowser(_ browser: BrowserData) async {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID) {
            app.terminate()
        }
        try? await Task.sleep(for: .seconds(1))
        refreshRunningStates()
    }

    func setItem(_ itemID: String, inBrowser browserID: String, selected: Bool) {
        guard let browserIndex = browsers.firstIndex(where: { $0.id == browserID }),
              let itemIndex = browsers[browserIndex].items.firstIndex(where: { $0.id == itemID })
        else { return }
        browsers[browserIndex].items[itemIndex].isSelected = selected
    }

    func cleanSelected() async {
        guard !isCleaning, cleanableSelectedCount > 0 else { return }
        refreshRunningStates()
        isCleaning = true

        let targets = browsers
            .filter { !$0.isRunning }
            .flatMap { browser in
                browser.items.filter(\.isSelected).map { (id: $0.id, url: $0.url, size: $0.size) }
            }
        let result = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(urls: targets, moveToTrash: true)
        }.value

        lastFreed = result.freed
        failures = result.failures
        history.record(
            source: "Privacy",
            files: targets.filter { result.cleanedIDs.contains($0.id) }
                .map { (path: $0.url.path, size: $0.size) },
            movedToTrash: true
        )
        for browserIndex in browsers.indices {
            browsers[browserIndex].items.removeAll { result.cleanedIDs.contains($0.id) }
        }
        browsers.removeAll { $0.items.isEmpty }
        isCleaning = false
    }

    private func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}
