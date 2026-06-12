import Foundation

enum UninstallerService {
    /// Lists third-party apps in /Applications and ~/Applications with sizes.
    static func scanApps() async -> [AppInfo] {
        let fm = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        var appURLs: [URL] = []
        for root in roots {
            guard let children = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            appURLs += children.filter { $0.pathExtension == "app" }
        }

        return await withTaskGroup(of: AppInfo?.self) { group in
            for url in appURLs {
                group.addTask {
                    let bundleID = Bundle(url: url)?.bundleIdentifier
                    // Hide Apple's own apps — uninstalling them is a bad idea.
                    if let bundleID, bundleID.hasPrefix("com.apple.") { return nil }
                    return AppInfo(url: url, bundleID: bundleID, size: FileSize.directorySize(at: url))
                }
            }
            var apps: [AppInfo] = []
            for await app in group {
                if let app { apps.append(app) }
            }
            return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// Finds support files, caches, preferences etc. left behind by an app.
    /// `library` is injectable for tests; defaults to the user's ~/Library.
    static func findLeftovers(for app: AppInfo, library: URL? = nil) -> [LeftoverItem] {
        let fm = FileManager.default
        let library = library ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        var candidates: [(path: String, kind: String)] = []

        func add(_ relative: String, _ kind: String) {
            candidates.append((relative, kind))
        }

        add("Application Support/\(app.name)", "Application Support")
        if let bundleID = app.bundleID {
            add("Application Support/\(bundleID)", "Application Support")
            add("Caches/\(bundleID)", "Caches")
            add("Preferences/\(bundleID).plist", "Preferences")
            add("Saved Application State/\(bundleID).savedState", "Saved State")
            add("Containers/\(bundleID)", "Containers")
            add("WebKit/\(bundleID)", "WebKit Data")
            add("HTTPStorages/\(bundleID)", "HTTP Storage")
            add("Application Scripts/\(bundleID)", "Application Scripts")
            add("Logs/\(bundleID)", "Logs")
        }
        add("Caches/\(app.name)", "Caches")
        add("Logs/\(app.name)", "Logs")

        var seen: Set<String> = []
        var items: [LeftoverItem] = []
        for candidate in candidates {
            let url = library.appendingPathComponent(candidate.path)
            guard !seen.contains(url.path), fm.fileExists(atPath: url.path) else { continue }
            seen.insert(url.path)
            items.append(LeftoverItem(url: url, kind: candidate.kind, size: FileSize.itemSize(at: url)))
        }

        // LaunchAgents matching the bundle ID prefix.
        if let bundleID = app.bundleID {
            let agents = library.appendingPathComponent("LaunchAgents")
            if let children = try? fm.contentsOfDirectory(at: agents, includingPropertiesForKeys: nil) {
                for url in children where url.lastPathComponent.hasPrefix(bundleID) {
                    guard !seen.contains(url.path) else { continue }
                    seen.insert(url.path)
                    items.append(LeftoverItem(url: url, kind: "Launch Agent", size: FileSize.itemSize(at: url)))
                }
            }
        }
        return items.sorted { $0.size > $1.size }
    }
}
