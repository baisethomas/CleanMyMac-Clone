import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExclusionsSettingsTab()
                .tabItem { Label("Exclusions", systemImage: "minus.circle") }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @State private var scheduleError: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Cleaning") {
                Toggle("Move cleaned files to Trash (recoverable)", isOn: $settings.moveToTrashDefault)
                Picker("Only flag caches", selection: $settings.cacheAgeDays) {
                    ForEach(AppSettings.cacheAgeOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                }
            }
            Section("Scheduled Scan") {
                Toggle("Scan for junk weekly in the background", isOn: scheduledScanBinding)
                Text("Runs Monday mornings and notifies you when junk is found. Requires the bundled app (built with Scripts/build-app.sh).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let scheduleError {
                    Label(scheduleError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Section("Permissions") {
                LabeledContent("Full Disk Access") {
                    if FullDiskAccess.hasAccess() {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open System Settings…") {
                            FullDiskAccess.openSystemSettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    private var scheduledScanBinding: Binding<Bool> {
        Binding(
            get: { settings.scheduledScanEnabled },
            set: { enabled in
                Task { scheduleError = await settings.setScheduledScan(enabled) }
            }
        )
    }
}

private struct ExclusionsSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Excluded folders and files are never flagged by junk scans.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            List {
                ForEach(settings.excludedPaths, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Remove", systemImage: "minus.circle.fill") {
                            settings.removeExclusion(path)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                if settings.excludedPaths.isEmpty {
                    Text("No exclusions")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 180)
            Button("Add Folder or File…", systemImage: "plus") {
                addExclusion()
            }
        }
        .padding(16)
    }

    private func addExclusion() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            settings.addExclusion(url)
        }
    }
}
