import Foundation
import UserNotifications

enum Notifier {
    /// Posts a local notification if the app is bundled and authorized.
    static func postJunkFound(_ size: Int64) async {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "MacCleaner"
        content.body = size > 0
            ? "\(Format.bytes(size)) of junk is ready to clean."
            : "Your Mac is clean — no junk found."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        try? await center.add(request)
    }
}

enum BackgroundScan {
    /// When launched by the scheduled launch agent, runs a headless junk scan,
    /// posts a notification with the result, and tells the caller to exit
    /// before any window is created.
    static func runIfRequested() -> Bool {
        let requested = ProcessInfo.processInfo.environment["MACCLEANER_BACKGROUND_SCAN"] == "1"
            || CommandLine.arguments.contains("--background-scan")
        guard requested else { return false }

        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .utility) {
            let options = ScanOptions.fromDefaults()
            var total: Int64 = 0
            for spec in JunkScanner.specs {
                total += await JunkScanner.scan(spec, options: options).totalSize
            }
            await Notifier.postJunkFound(total)
            semaphore.signal()
        }
        // Main thread blocks here; the scan runs on the cooperative pool.
        semaphore.wait()
        return true
    }
}
