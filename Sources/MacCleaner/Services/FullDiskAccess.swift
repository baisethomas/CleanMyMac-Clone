import AppKit

enum FullDiskAccess {
    /// Heuristic: ~/Library/Safari is TCC-protected, so listing it only
    /// succeeds when the app has Full Disk Access.
    static func hasAccess() -> Bool {
        let probe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        return (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil
    }

    @MainActor
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
