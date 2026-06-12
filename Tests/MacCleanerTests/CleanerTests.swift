import Testing
import Foundation
@testable import MacCleaner

struct CleanerTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func permanentDeleteRemovesFilesAndReportsFreedBytes() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileA = dir.appendingPathComponent("a.txt")
        let fileB = dir.appendingPathComponent("b.txt")
        try Data(repeating: 1, count: 100).write(to: fileA)
        try Data(repeating: 2, count: 200).write(to: fileB)

        let result = Cleaner.clean(
            urls: [
                (id: "a", url: fileA, size: 100),
                (id: "b", url: fileB, size: 200),
            ],
            moveToTrash: false
        )

        #expect(result.freed == 300)
        #expect(result.cleanedIDs == ["a", "b"])
        #expect(result.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileA.path))
        #expect(!FileManager.default.fileExists(atPath: fileB.path))
    }

    @Test func missingFileIsReportedAsFailure() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let missing = dir.appendingPathComponent("nope.txt")
        let result = Cleaner.clean(
            urls: [(id: "missing", url: missing, size: 50)],
            moveToTrash: false
        )

        #expect(result.freed == 0)
        #expect(result.cleanedIDs.isEmpty)
        #expect(result.failures.count == 1)
    }

    @Test func directorySizeSumsRegularFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let nested = dir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 10_000).write(to: dir.appendingPathComponent("one.bin"))
        try Data(repeating: 0, count: 20_000).write(to: nested.appendingPathComponent("two.bin"))

        // Allocated size is block-rounded, so expect at least the byte count.
        let size = FileSize.directorySize(at: dir)
        #expect(size >= 30_000)
    }
}
