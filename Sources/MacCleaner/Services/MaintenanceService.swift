import Foundation

enum MaintenanceService {
    static let tasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "freeRAM", name: "Free Up RAM",
            detail: "Purge inactive memory so active apps get more headroom",
            icon: "memorychip", command: "purge", needsAdmin: true
        ),
        MaintenanceTask(
            id: "flushDNS", name: "Flush DNS Cache",
            detail: "Clear cached DNS lookups to fix stale or broken name resolution",
            icon: "network", command: "dscacheutil -flushcache; killall -HUP mDNSResponder",
            needsAdmin: true
        ),
        MaintenanceTask(
            id: "spotlight", name: "Reindex Spotlight",
            detail: "Erase and rebuild the Spotlight index on the startup disk",
            icon: "magnifyingglass", command: "mdutil -E /", needsAdmin: true
        ),
        MaintenanceTask(
            id: "launchServices", name: "Rebuild Launch Services",
            detail: "Fix duplicate \"Open With\" menu entries and wrong file associations",
            icon: "menubar.rectangle",
            command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user",
            needsAdmin: false
        ),
        MaintenanceTask(
            id: "periodic", name: "Run Maintenance Scripts",
            detail: "Run macOS daily, weekly and monthly periodic scripts",
            icon: "calendar.badge.clock", command: "periodic daily weekly monthly",
            needsAdmin: true
        ),
        MaintenanceTask(
            id: "tmSnapshots", name: "Clear Time Machine Snapshots",
            detail: "Delete local APFS snapshots that can silently hold tens of GB",
            icon: "clock.arrow.circlepath",
            command: "tmutil listlocalsnapshotdates / | tail -n +2 | while read d; do tmutil deletelocalsnapshots $d; done",
            needsAdmin: true
        ),
        MaintenanceTask(
            id: "emptyTrash", name: "Empty Trash",
            detail: "Permanently delete everything in your Trash",
            icon: "trash.slash", command: "rm -rf ~/.Trash/*", needsAdmin: false
        ),
    ]

    static func run(_ task: MaintenanceTask) async -> ShellResult {
        if task.needsAdmin {
            await Shell.admin(task.command)
        } else {
            await Shell.zsh(task.command)
        }
    }
}
