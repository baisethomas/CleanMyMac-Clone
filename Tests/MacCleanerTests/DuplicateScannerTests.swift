import Testing
import Foundation
@testable import MacCleaner

struct DuplicateScannerTests {
    private func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DupTests-\(UUID().uuidString)")
        let sub = root.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

        let identical = Data(repeating: 7, count: 5000)
        let sameSizeDifferentContent = Data(repeating: 8, count: 5000)
        let unique = Data(repeating: 9, count: 6000)

        try identical.write(to: root.appendingPathComponent("copy1.bin"))
        try identical.write(to: sub.appendingPathComponent("copy2.bin"))
        try identical.write(to: sub.appendingPathComponent("copy3.bin"))
        try sameSizeDifferentContent.write(to: root.appendingPathComponent("decoy.bin"))
        try unique.write(to: root.appendingPathComponent("unique.bin"))
        return root
    }

    @Test func findsIdenticalFilesAndIgnoresDecoys() async throws {
        let root = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let groups = await DuplicateScanner.scan(root: root, minSize: 1)

        #expect(groups.count == 1)
        let group = try #require(groups.first)
        #expect(group.files.count == 3)
        #expect(group.fileSize == 5000)
        #expect(group.wastedSize == 10000)
        // Auto-selection keeps exactly one copy.
        #expect(group.selectedCount == 2)
    }

    @Test func respectsMinimumSize() async throws {
        let root = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let groups = await DuplicateScanner.scan(root: root, minSize: 10_000)
        #expect(groups.isEmpty)
    }

    @Test func keepOldestSelectsAllButLast() throws {
        let files = [
            DuplicateFile(url: URL(fileURLWithPath: "/tmp/new"), modified: Date(timeIntervalSince1970: 300)),
            DuplicateFile(url: URL(fileURLWithPath: "/tmp/mid"), modified: Date(timeIntervalSince1970: 200)),
            DuplicateFile(url: URL(fileURLWithPath: "/tmp/old"), modified: Date(timeIntervalSince1970: 100)),
        ]
        var group = DuplicateGroup(id: "x", fileSize: 10, files: files)

        DuplicateScanner.selectAllButOldest(&group)
        #expect(group.files[0].isSelected)
        #expect(group.files[1].isSelected)
        #expect(!group.files[2].isSelected)

        DuplicateScanner.selectAllButNewest(&group)
        #expect(!group.files[0].isSelected)
        #expect(group.files[1].isSelected)
        #expect(group.files[2].isSelected)
    }
}
