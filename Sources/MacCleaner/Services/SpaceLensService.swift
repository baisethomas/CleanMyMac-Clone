import Foundation

enum SpaceLensService {
    /// Immediate children of a directory with their (recursive) sizes, largest first.
    static func entries(of url: URL) -> [FolderEntry] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey]
        guard let children = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: Array(keys), options: []
        ) else { return [] }

        return children
            .compactMap { child -> FolderEntry? in
                let values = try? child.resourceValues(forKeys: keys)
                let isPackage = values?.isPackage ?? false
                let isDirectory = (values?.isDirectory ?? false) && !isPackage
                let size = FileSize.itemSize(at: child)
                guard size > 0 else { return nil }
                return FolderEntry(url: child, size: size, isDirectory: isDirectory)
            }
            .sorted { $0.size > $1.size }
    }
}
