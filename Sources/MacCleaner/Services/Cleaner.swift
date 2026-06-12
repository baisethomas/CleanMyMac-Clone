import Foundation

struct CleanResult: Sendable {
    let freed: Int64
    let cleanedIDs: Set<String>
    let failures: [String]
}

enum Cleaner {
    /// Removes the given URLs. Items already in the Trash are deleted permanently;
    /// everything else is moved to the Trash unless `moveToTrash` is false.
    static func clean(urls: [(id: String, url: URL, size: Int64)], moveToTrash: Bool) -> CleanResult {
        let fm = FileManager.default
        let trashPath = fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        var freed: Int64 = 0
        var cleaned: Set<String> = []
        var failures: [String] = []

        for item in urls {
            do {
                if !moveToTrash || item.url.path.hasPrefix(trashPath) {
                    try fm.removeItem(at: item.url)
                } else {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                }
                freed += item.size
                cleaned.insert(item.id)
            } catch {
                failures.append("\(item.url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return CleanResult(freed: freed, cleanedIDs: cleaned, failures: failures)
    }
}
