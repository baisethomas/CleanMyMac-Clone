import Testing
import Foundation
@testable import MacCleaner

struct UninstallerLeftoverTests {
    @Test func findsLeftoversByBundleIDAndName() throws {
        let library = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibFixture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: library) }

        let fm = FileManager.default
        let bundleID = "com.example.testapp"

        try fm.createDirectory(
            at: library.appendingPathComponent("Application Support/TestApp"),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(
            at: library.appendingPathComponent("Caches/\(bundleID)"),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(
            at: library.appendingPathComponent("Preferences"),
            withIntermediateDirectories: true
        )
        try Data("plist".utf8).write(
            to: library.appendingPathComponent("Preferences/\(bundleID).plist")
        )
        try fm.createDirectory(
            at: library.appendingPathComponent("LaunchAgents"),
            withIntermediateDirectories: true
        )
        try Data("agent".utf8).write(
            to: library.appendingPathComponent("LaunchAgents/\(bundleID).helper.plist")
        )
        // Unrelated noise that must not be flagged.
        try fm.createDirectory(
            at: library.appendingPathComponent("Application Support/OtherApp"),
            withIntermediateDirectories: true
        )

        let app = AppInfo(
            url: URL(fileURLWithPath: "/Applications/TestApp.app"),
            bundleID: bundleID,
            size: 1
        )
        let leftovers = UninstallerService.findLeftovers(for: app, library: library)
        let paths = Set(leftovers.map(\.url.lastPathComponent))

        #expect(paths.contains("TestApp"))
        #expect(paths.contains(bundleID))
        #expect(paths.contains("\(bundleID).plist"))
        #expect(paths.contains("\(bundleID).helper.plist"))
        #expect(!paths.contains("OtherApp"))
    }

    @Test func appWithoutBundleIDOnlyMatchesByName() throws {
        let library = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibFixture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: library) }

        try FileManager.default.createDirectory(
            at: library.appendingPathComponent("Application Support/NoBundle"),
            withIntermediateDirectories: true
        )

        let app = AppInfo(
            url: URL(fileURLWithPath: "/Applications/NoBundle.app"),
            bundleID: nil,
            size: 1
        )
        let leftovers = UninstallerService.findLeftovers(for: app, library: library)
        #expect(leftovers.count == 1)
        #expect(leftovers.first?.url.lastPathComponent == "NoBundle")
    }
}
