import Foundation
import CryptoKit

struct DuplicateFile: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let modified: Date?
    var isSelected: Bool

    init(url: URL, modified: Date?) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.modified = modified
        self.isSelected = false
    }
}

struct DuplicateGroup: Identifiable, Sendable {
    let id: String
    let fileSize: Int64
    var files: [DuplicateFile]

    var wastedSize: Int64 { fileSize * Int64(max(files.count - 1, 0)) }
    var selectedCount: Int { files.count(where: \.isSelected) }
    var selectedSize: Int64 { fileSize * Int64(selectedCount) }
}

enum DuplicateScanner {
    /// Finds files with identical content under `root` (default: home folder,
    /// skipping ~/Library, hidden files and package contents).
    ///
    /// Three passes keep it fast: group by byte size, then by a hash of the
    /// first 128 KB, then by a full streaming hash — so full reads only happen
    /// for genuine collision candidates.
    static func scan(
        root: URL = FileManager.default.homeDirectoryForCurrentUser,
        minSize: Int64
    ) async -> [DuplicateGroup] {
        let bySize = filesBySize(root: root, minSize: minSize)
        return await withTaskGroup(of: [DuplicateGroup].self) { group in
            for (size, urls) in bySize where urls.count > 1 {
                group.addTask {
                    resolveGroups(size: size, urls: urls)
                }
            }
            var groups: [DuplicateGroup] = []
            for await resolved in group {
                groups += resolved
            }
            return groups.sorted { $0.wastedSize > $1.wastedSize }
        }
    }

    // MARK: - Pass 1: size buckets

    private static func filesBySize(root: URL, minSize: Int64) -> [Int64: [URL]] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [:] }

        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library").path
        var bySize: [Int64: [URL]] = [:]
        for case let url as URL in enumerator {
            if url.path.hasPrefix(library) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize.map(Int64.init),
                  size >= minSize else { continue }
            bySize[size, default: []].append(url)
        }
        return bySize
    }

    // MARK: - Passes 2 & 3: content hashing

    private static func resolveGroups(size: Int64, urls: [URL]) -> [DuplicateGroup] {
        var byPartial: [String: [URL]] = [:]
        for url in urls {
            guard let hash = contentHash(url, limit: 128 * 1024) else { continue }
            byPartial[hash, default: []].append(url)
        }

        var groups: [DuplicateGroup] = []
        for candidates in byPartial.values where candidates.count > 1 {
            var byFull: [String: [URL]] = [:]
            for url in candidates {
                guard let hash = contentHash(url, limit: nil) else { continue }
                byFull[hash, default: []].append(url)
            }
            for (fullHash, dupes) in byFull where dupes.count > 1 {
                let files = dupes
                    .map { url in
                        DuplicateFile(
                            url: url,
                            modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                                .contentModificationDate
                        )
                    }
                    .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
                var group = DuplicateGroup(id: fullHash, fileSize: size, files: files)
                selectAllButNewest(&group)
                groups.append(group)
            }
        }
        return groups
    }

    static func selectAllButNewest(_ group: inout DuplicateGroup) {
        // Files are sorted newest-first.
        for index in group.files.indices {
            group.files[index].isSelected = index > 0
        }
    }

    static func selectAllButOldest(_ group: inout DuplicateGroup) {
        let last = group.files.indices.last
        for index in group.files.indices {
            group.files[index].isSelected = index != last
        }
    }

    private static func contentHash(_ url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1 << 20
        var remaining = limit ?? .max
        while remaining > 0 {
            guard let data = try? handle.read(upToCount: min(chunkSize, remaining)),
                  !data.isEmpty else { break }
            hasher.update(data: data)
            remaining -= data.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
