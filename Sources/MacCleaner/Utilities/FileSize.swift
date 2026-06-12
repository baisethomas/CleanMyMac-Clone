import Foundation

enum FileSize {
    /// Recursive allocated size of a directory. Unreadable entries are skipped.
    static func directorySize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// Size of a file or directory at the given URL.
    static func itemSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if isDirectory.boolValue {
            return directorySize(at: url)
        }
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? 0)
    }
}
