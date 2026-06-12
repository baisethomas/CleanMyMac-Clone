import Foundation

struct LaunchAgent: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let label: String
    let program: String
    let isEnabled: Bool
}

enum LaunchAgentService {
    private static let disabledSuffix = ".disabled"

    /// User launch agents in ~/Library/LaunchAgents. Agents disabled by this
    /// app carry a `.disabled` filename suffix.
    static func list() -> [LaunchAgent] {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        guard let children = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        return children
            .filter {
                $0.lastPathComponent.hasSuffix(".plist")
                    || $0.lastPathComponent.hasSuffix(".plist" + disabledSuffix)
            }
            .compactMap { url in
                let isEnabled = !url.lastPathComponent.hasSuffix(disabledSuffix)
                guard let data = try? Data(contentsOf: url),
                      let plist = try? PropertyListSerialization.propertyList(
                        from: data, format: nil
                      ) as? [String: Any] else {
                    return LaunchAgent(
                        id: url.path, url: url,
                        label: url.deletingPathExtension().lastPathComponent,
                        program: "(unreadable plist)", isEnabled: isEnabled
                    )
                }
                let label = plist["Label"] as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let program = plist["Program"] as? String
                    ?? (plist["ProgramArguments"] as? [String])?.first
                    ?? "—"
                return LaunchAgent(
                    id: url.path, url: url, label: label,
                    program: program, isEnabled: isEnabled
                )
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    /// Enables or disables an agent: unload/load with launchctl plus a
    /// filename marker so the state survives reboots.
    static func setEnabled(_ agent: LaunchAgent, enabled: Bool) async -> String? {
        let fm = FileManager.default
        let uid = getuid()
        do {
            if enabled {
                let activeURL = URL(fileURLWithPath: String(
                    agent.url.path.dropLast(disabledSuffix.count)
                ))
                try fm.moveItem(at: agent.url, to: activeURL)
                _ = await Shell.run("/bin/launchctl", ["bootstrap", "gui/\(uid)", activeURL.path])
            } else {
                // Bootout may fail if not loaded — that's fine, the rename is what persists.
                _ = await Shell.run("/bin/launchctl", ["bootout", "gui/\(uid)/\(agent.label)"])
                let disabledURL = URL(fileURLWithPath: agent.url.path + disabledSuffix)
                try fm.moveItem(at: agent.url, to: disabledURL)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
