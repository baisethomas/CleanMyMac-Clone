import Foundation
import Observation

@MainActor @Observable
final class SpaceLensModel {
    private(set) var pathStack: [URL] = [FileManager.default.homeDirectoryForCurrentUser]
    private(set) var entries: [FolderEntry] = []
    private(set) var isLoading = false
    private(set) var hasScanned = false

    var currentURL: URL { pathStack[pathStack.count - 1] }
    var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }

    func load() async {
        isLoading = true
        let url = currentURL
        entries = await Task.detached(priority: .userInitiated) {
            SpaceLensService.entries(of: url)
        }.value
        hasScanned = true
        isLoading = false
    }

    func open(_ entry: FolderEntry) async {
        guard entry.isDirectory else { return }
        pathStack.append(entry.url)
        await load()
    }

    func jump(to index: Int) async {
        guard index < pathStack.count - 1 else { return }
        pathStack.removeLast(pathStack.count - 1 - index)
        await load()
    }
}
