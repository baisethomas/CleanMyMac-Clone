import SwiftUI

@main
struct MacCleanerApp: App {
    @State private var appModel: AppModel

    init() {
        // Launched by the scheduled launch agent: scan, notify, exit —
        // before any window or model is created.
        if BackgroundScan.runIfRequested() {
            exit(0)
        }
        // Ensures the window comes to front when launched from a bare
        // executable (`swift run`) rather than the bundled .app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        _appModel = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup("MacCleaner", id: "main") {
            ContentView()
                .frame(minWidth: 1020, minHeight: 680)
                .appEnvironment(appModel)
        }

        MenuBarExtra("MacCleaner", systemImage: "sparkles") {
            MenuBarView()
                .appEnvironment(appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .appEnvironment(appModel)
        }
    }
}
