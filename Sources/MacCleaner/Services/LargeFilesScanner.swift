import Foundation

enum LargeFilesScanner {
    /// Scans the home directory for regular files of at least `minSize` bytes.
    /// `~/Library` and hidden files are skipped. Returns the largest `limit` files.
    static func scan(minSize: Int64, limit: Int = 300) -> [LargeFile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey, .isRegularFileKey, .contentAccessDateKey
        ]
        guard let enumerator = fm.enumerator(
            at: home,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let library = home.appendingPathComponent("Library").path
        var results: [LargeFile] = []

        for case let url as URL in enumerator {
            if url.path.hasPrefix(library) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize.map(Int64.init),
                  size >= minSize else { continue }
            results.append(LargeFile(url: url, size: size, lastAccessed: values.contentAccessDate))
        }
        return Array(results.sorted { $0.size > $1.size }.prefix(limit))
    }
}
