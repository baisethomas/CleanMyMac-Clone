import Foundation

// MARK: - Cleanable items (System Junk / Smart Scan)

struct CleanableItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let size: Int64
    var isSelected: Bool

    init(url: URL, size: Int64, isSelected: Bool) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.isSelected = isSelected
    }
}

/// How risky it is to delete a category's contents without reviewing them.
enum SafetyLevel: String, Sendable {
    case safe
    case review
}

struct JunkCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let tint: CategoryTint
    let safety: SafetyLevel
    var items: [CleanableItem]

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.count(where: \.isSelected) }
    var allSelected: Bool { !items.isEmpty && items.allSatisfy(\.isSelected) }
}

/// Color names resolved in the view layer so model types stay free of SwiftUI.
enum CategoryTint: String, Sendable {
    case blue, purple, orange, red, green, teal, pink, yellow
}

// MARK: - Large & Old Files

struct LargeFile: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let size: Int64
    let lastAccessed: Date?

    init(url: URL, size: Int64, lastAccessed: Date?) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.lastAccessed = lastAccessed
    }
}

// MARK: - Uninstaller

struct AppInfo: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let bundleID: String?
    let size: Int64

    init(url: URL, bundleID: String?, size: Int64) {
        self.id = url.path
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.bundleID = bundleID
        self.size = size
    }
}

struct LeftoverItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let kind: String
    let size: Int64
    var isSelected: Bool

    init(url: URL, kind: String, size: Int64) {
        self.id = url.path
        self.url = url
        self.kind = kind
        self.size = size
        self.isSelected = true
    }
}

// MARK: - Maintenance

struct MaintenanceTask: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let command: String
    let needsAdmin: Bool
}

// MARK: - Space Lens

struct FolderEntry: Identifiable, Sendable {
    let id: String
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool

    init(url: URL, size: Int64, isDirectory: Bool) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.isDirectory = isDirectory
    }
}

// MARK: - System stats

struct DiskStats: Sendable {
    let total: Int64
    let free: Int64
    var used: Int64 { total - free }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct MemoryStats: Sendable {
    let total: Int64
    let used: Int64
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}
