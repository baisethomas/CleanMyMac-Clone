import Foundation
import Observation
import ServiceManagement
import UserNotifications

/// Sendable snapshot of scan-relevant settings, passed into nonisolated scanners.
struct ScanOptions: Sendable {
    var cacheAgeDays: Int
    var excludedPaths: [String]

    func isExcluded(_ url: URL) -> Bool {
        let path = url.path
        return excludedPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    static func fromDefaults() -> ScanOptions {
        let defaults = UserDefaults.standard
        return ScanOptions(
            cacheAgeDays: defaults.integer(forKey: SettingsKey.cacheAgeDays),
            excludedPaths: defaults.stringArray(forKey: SettingsKey.excludedPaths) ?? []
        )
    }
}

enum SettingsKey {
    static let moveToTrash = "moveToTrashDefault"
    static let cacheAgeDays = "cacheAgeDays"
    static let excludedPaths = "excludedPaths"
}

@MainActor @Observable
final class AppSettings {
    var moveToTrashDefault: Bool {
        didSet { defaults.set(moveToTrashDefault, forKey: SettingsKey.moveToTrash) }
    }
    /// Only caches untouched for this many days are flagged (0 = all).
    var cacheAgeDays: Int {
        didSet { defaults.set(cacheAgeDays, forKey: SettingsKey.cacheAgeDays) }
    }
    private(set) var excludedPaths: [String] {
        didSet { defaults.set(excludedPaths, forKey: SettingsKey.excludedPaths) }
    }
    private(set) var scheduledScanEnabled: Bool

    @ObservationIgnored private let defaults = UserDefaults.standard

    static let cacheAgeOptions: [(label: String, days: Int)] = [
        ("Any age", 0), ("Older than 7 days", 7), ("Older than 30 days", 30), ("Older than 90 days", 90),
    ]

    private static let agentService = SMAppService.agent(plistName: "dev.baisethomas.maccleaner.agent.plist")

    init() {
        moveToTrashDefault = defaults.object(forKey: SettingsKey.moveToTrash) as? Bool ?? true
        cacheAgeDays = defaults.integer(forKey: SettingsKey.cacheAgeDays)
        excludedPaths = defaults.stringArray(forKey: SettingsKey.excludedPaths) ?? []
        scheduledScanEnabled = Self.agentService.status == .enabled
    }

    var scanOptions: ScanOptions {
        ScanOptions(cacheAgeDays: cacheAgeDays, excludedPaths: excludedPaths)
    }

    func addExclusion(_ url: URL) {
        let path = url.path
        guard !excludedPaths.contains(path) else { return }
        excludedPaths.append(path)
        excludedPaths.sort()
    }

    func removeExclusion(_ path: String) {
        excludedPaths.removeAll { $0 == path }
    }

    /// Registers/unregisters the weekly background-scan launch agent.
    /// Returns an error message on failure (e.g. when running unbundled).
    func setScheduledScan(_ enabled: Bool) async -> String? {
        defer { scheduledScanEnabled = Self.agentService.status == .enabled }
        do {
            if enabled {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                try Self.agentService.register()
            } else {
                try await Self.agentService.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
