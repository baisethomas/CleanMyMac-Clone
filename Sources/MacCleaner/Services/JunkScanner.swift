import Foundation

struct JunkCategorySpec: Sendable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let tint: CategoryTint
    let safety: SafetyLevel
    let defaultSelected: Bool
}

enum JunkScanner {
    static let specs: [JunkCategorySpec] = [
        JunkCategorySpec(
            id: "userCaches", name: "User Caches",
            detail: "Application cache files that apps rebuild as needed",
            icon: "internaldrive", tint: .blue, safety: .safe, defaultSelected: true
        ),
        JunkCategorySpec(
            id: "logs", name: "Logs & Diagnostics",
            detail: "Application logs and diagnostic reports",
            icon: "doc.text", tint: .orange, safety: .safe, defaultSelected: true
        ),
        JunkCategorySpec(
            id: "xcode", name: "Xcode Junk",
            detail: "Derived data, device support files and simulator caches",
            icon: "hammer", tint: .purple, safety: .safe, defaultSelected: true
        ),
        JunkCategorySpec(
            id: "devCaches", name: "Development Caches",
            detail: "Package manager caches (npm, pip, Cargo, Gradle…)",
            icon: "shippingbox", tint: .teal, safety: .safe, defaultSelected: true
        ),
        JunkCategorySpec(
            id: "mail", name: "Mail Attachments",
            detail: "Attachments Mail has downloaded — re-downloadable from the server",
            icon: "envelope", tint: .pink, safety: .review, defaultSelected: false
        ),
        JunkCategorySpec(
            id: "screenshots", name: "Old Screenshots",
            detail: "Desktop screenshots and screen recordings older than 30 days",
            icon: "camera.viewfinder", tint: .yellow, safety: .review, defaultSelected: false
        ),
        JunkCategorySpec(
            id: "trash", name: "Trash",
            detail: "Items sitting in your Trash",
            icon: "trash", tint: .red, safety: .review, defaultSelected: false
        ),
        JunkCategorySpec(
            id: "installers", name: "Old Installers",
            detail: "Disk images and installer packages in Downloads",
            icon: "arrow.down.circle", tint: .green, safety: .review, defaultSelected: false
        ),
    ]

    static func scan(_ spec: JunkCategorySpec, options: ScanOptions) async -> JunkCategory {
        let items: [CleanableItem]
        switch spec.id {
        case "userCaches":
            items = await childItems(
                of: home("Library/Caches"), spec: spec, options: options,
                olderThanDays: options.cacheAgeDays
            )
        case "logs":
            items = await childItems(of: home("Library/Logs"), spec: spec, options: options)
                + childItems(of: home("Library/DiagnosticReports"), spec: spec, options: options)
        case "xcode":
            items = await childItems(of: home("Library/Developer/Xcode/DerivedData"), spec: spec, options: options)
                + childItems(of: home("Library/Developer/Xcode/iOS DeviceSupport"), spec: spec, options: options)
                + childItems(of: home("Library/Developer/CoreSimulator/Caches"), spec: spec, options: options)
        case "devCaches":
            items = await existingItems(at: [
                home(".npm/_cacache"),
                home(".cache"),
                home(".gradle/caches"),
                home(".cargo/registry/cache"),
                home("Library/Caches/pip"),
                home(".cocoapods/repos"),
            ], spec: spec, options: options)
        case "mail":
            items = await childItems(
                of: home("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
                spec: spec, options: options
            )
        case "screenshots":
            items = await screenshotItems(spec: spec, options: options)
        case "trash":
            items = await childItems(of: home(".Trash"), spec: spec, options: options)
        case "installers":
            items = await installerItems(spec: spec, options: options)
        default:
            items = []
        }
        return JunkCategory(
            id: spec.id, name: spec.name, detail: spec.detail,
            icon: spec.icon, tint: spec.tint, safety: spec.safety,
            items: items.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        )
    }

    // MARK: - Helpers

    private static func home(_ path: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path)
    }

    /// Sizes URLs concurrently — directory traversal dominates scan time.
    private static func sized(_ urls: [URL], selected: Bool) async -> [CleanableItem] {
        await withTaskGroup(of: CleanableItem.self) { group in
            for url in urls {
                group.addTask {
                    CleanableItem(url: url, size: FileSize.itemSize(at: url), isSelected: selected)
                }
            }
            var items: [CleanableItem] = []
            for await item in group {
                items.append(item)
            }
            return items
        }
    }

    /// One item per immediate child of the directory, respecting exclusions
    /// and an optional minimum age (by last modification).
    private static func childItems(
        of url: URL,
        spec: JunkCategorySpec,
        options: ScanOptions,
        olderThanDays: Int = 0
    ) async -> [CleanableItem] {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = olderThanDays > 0
            ? Date.now.addingTimeInterval(-Double(olderThanDays) * 86400)
            : nil

        let eligible = children.filter { child in
            if options.isExcluded(child) { return false }
            guard let cutoff else { return true }
            let modified = (try? child.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return modified < cutoff
        }
        return await sized(eligible, selected: spec.defaultSelected)
    }

    /// One item per path that exists.
    private static func existingItems(
        at urls: [URL], spec: JunkCategorySpec, options: ScanOptions
    ) async -> [CleanableItem] {
        let existing = urls.filter {
            !options.isExcluded($0) && FileManager.default.fileExists(atPath: $0.path)
        }
        return await sized(existing, selected: spec.defaultSelected)
    }

    private static func installerItems(
        spec: JunkCategorySpec, options: ScanOptions
    ) async -> [CleanableItem] {
        let downloads = home("Downloads")
        let extensions: Set<String> = ["dmg", "pkg", "iso", "xip"]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: downloads, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }
        let matches = children.filter {
            extensions.contains($0.pathExtension.lowercased()) && !options.isExcluded($0)
        }
        return await sized(matches, selected: spec.defaultSelected)
    }

    private static func screenshotItems(
        spec: JunkCategorySpec, options: ScanOptions
    ) async -> [CleanableItem] {
        let desktop = home("Desktop")
        let prefixes = ["Screenshot", "Screen Shot", "Screen Recording"]
        let cutoff = Date.now.addingTimeInterval(-30 * 86400)
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: desktop,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let matches = children.filter { child in
            guard prefixes.contains(where: { child.lastPathComponent.hasPrefix($0) }),
                  !options.isExcluded(child) else { return false }
            let created = (try? child.resourceValues(forKeys: [.creationDateKey]))?
                .creationDate ?? .distantFuture
            return created < cutoff
        }
        return await sized(matches, selected: spec.defaultSelected)
    }
}
