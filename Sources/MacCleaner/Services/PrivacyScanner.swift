import Foundation

struct BrowserDataItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let kind: String
    let size: Int64
    var isSelected: Bool

    init(url: URL, kind: String, size: Int64, isSelected: Bool) {
        self.id = url.path
        self.url = url
        self.kind = kind
        self.size = size
        self.isSelected = isSelected
    }
}

struct BrowserData: Identifiable, Sendable {
    let id: String
    let name: String
    let bundleID: String
    var appPath: String?
    var items: [BrowserDataItem]
    var isRunning = false

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.count(where: \.isSelected) }
}

enum PrivacyScanner {
    private struct BrowserSpec {
        let name: String
        let bundleID: String
        /// (kind, home-relative path, selected by default)
        let paths: [(kind: String, path: String, selected: Bool)]
    }

    private static let specs: [BrowserSpec] = [
        BrowserSpec(name: "Safari", bundleID: "com.apple.Safari", paths: [
            ("Cache", "Library/Caches/com.apple.Safari", true),
            ("History", "Library/Safari/History.db", false),
            ("Cookies", "Library/Cookies/Cookies.binarycookies", false),
        ]),
        BrowserSpec(name: "Google Chrome", bundleID: "com.google.Chrome", paths: [
            ("Cache", "Library/Caches/Google/Chrome", true),
            ("History", "Library/Application Support/Google/Chrome/Default/History", false),
            ("Cookies", "Library/Application Support/Google/Chrome/Default/Cookies", false),
        ]),
        BrowserSpec(name: "Arc", bundleID: "company.thebrowser.Browser", paths: [
            ("Cache", "Library/Caches/Arc", true),
            ("History", "Library/Application Support/Arc/User Data/Default/History", false),
            ("Cookies", "Library/Application Support/Arc/User Data/Default/Cookies", false),
        ]),
        BrowserSpec(name: "Brave", bundleID: "com.brave.Browser", paths: [
            ("Cache", "Library/Caches/BraveSoftware/Brave-Browser", true),
            ("History", "Library/Application Support/BraveSoftware/Brave-Browser/Default/History", false),
            ("Cookies", "Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies", false),
        ]),
        BrowserSpec(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", paths: [
            ("Cache", "Library/Caches/Microsoft Edge", true),
            ("History", "Library/Application Support/Microsoft Edge/Default/History", false),
            ("Cookies", "Library/Application Support/Microsoft Edge/Default/Cookies", false),
        ]),
        BrowserSpec(name: "Firefox", bundleID: "org.mozilla.firefox", paths: [
            ("Cache", "Library/Caches/Firefox", true),
        ]),
    ]

    /// Browsers that have measurable data on disk. Running state and app
    /// paths are filled in by the model on the main actor.
    static func scan() async -> [BrowserData] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var browsers: [BrowserData] = []

        for spec in specs {
            var candidates = spec.paths.map {
                (kind: $0.kind, url: home.appendingPathComponent($0.path), selected: $0.selected)
            }
            // Firefox keeps history/cookies inside per-profile folders.
            if spec.bundleID == "org.mozilla.firefox" {
                let profiles = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
                if let dirs = try? FileManager.default.contentsOfDirectory(
                    at: profiles, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
                ) {
                    for profile in dirs {
                        candidates.append((kind: "History", url: profile.appendingPathComponent("places.sqlite"), selected: false))
                        candidates.append((kind: "Cookies", url: profile.appendingPathComponent("cookies.sqlite"), selected: false))
                    }
                }
            }

            let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.url.path) }
            guard !existing.isEmpty else { continue }

            let items = await withTaskGroup(of: BrowserDataItem.self) { group in
                for candidate in existing {
                    group.addTask {
                        BrowserDataItem(
                            url: candidate.url,
                            kind: candidate.kind,
                            size: FileSize.itemSize(at: candidate.url),
                            isSelected: candidate.selected
                        )
                    }
                }
                var collected: [BrowserDataItem] = []
                for await item in group {
                    collected.append(item)
                }
                return collected.sorted { $0.size > $1.size }
            }

            browsers.append(BrowserData(
                id: spec.bundleID, name: spec.name, bundleID: spec.bundleID,
                appPath: nil, items: items.filter { $0.size > 0 }
            ))
        }
        return browsers
            .filter { !$0.items.isEmpty }
            .sorted { $0.totalSize > $1.totalSize }
    }
}
