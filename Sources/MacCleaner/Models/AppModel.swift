import SwiftUI
import Observation

/// Owns every feature model so the main window, menu bar extra and Settings
/// scene all share the same state.
@MainActor @Observable
final class AppModel {
    let settings: AppSettings
    let history: HistoryStore
    let junk: JunkModel
    let stats = StatsModel()
    let largeFiles: LargeFilesModel
    let uninstaller: UninstallerModel
    let maintenance = MaintenanceModel()
    let spaceLens = SpaceLensModel()
    let duplicates: DuplicatesModel
    let optimization = OptimizationModel()
    let privacy: PrivacyModel

    init() {
        let settings = AppSettings()
        let history = HistoryStore()
        self.settings = settings
        self.history = history
        self.junk = JunkModel(settings: settings, history: history)
        self.largeFiles = LargeFilesModel(history: history)
        self.uninstaller = UninstallerModel(history: history)
        self.duplicates = DuplicatesModel(settings: settings, history: history)
        self.privacy = PrivacyModel(history: history)
    }
}

extension View {
    /// Injects every feature model into the environment.
    func appEnvironment(_ app: AppModel) -> some View {
        environment(app.settings)
            .environment(app.history)
            .environment(app.junk)
            .environment(app.stats)
            .environment(app.largeFiles)
            .environment(app.uninstaller)
            .environment(app.maintenance)
            .environment(app.spaceLens)
            .environment(app.duplicates)
            .environment(app.optimization)
            .environment(app.privacy)
    }
}
