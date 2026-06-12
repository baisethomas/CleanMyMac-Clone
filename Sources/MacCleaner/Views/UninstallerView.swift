import SwiftUI

struct UninstallerView: View {
    @Environment(UninstallerModel.self) private var uninstaller
    @State private var confirmingUninstall = false

    var body: some View {
        @Bindable var uninstaller = uninstaller
        HSplitView {
            appList
                .frame(minWidth: 280, idealWidth: 320)
            detail
                .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Uninstaller")
        .searchable(text: $uninstaller.searchText, prompt: "Search apps")
        .task {
            if !uninstaller.hasScanned {
                await uninstaller.scanApps()
            }
        }
        .confirmationDialog(
            "Uninstall \(uninstaller.selectedApp?.name ?? "app")?",
            isPresented: $confirmingUninstall
        ) {
            Button("Move App & Leftovers to Trash", role: .destructive) {
                Task { await uninstaller.uninstallSelected() }
            }
        } message: {
            Text("The app and the selected leftover files will be moved to the Trash.")
        }
    }

    // MARK: - App list

    @ViewBuilder
    private var appList: some View {
        @Bindable var uninstaller = uninstaller
        Group {
            if uninstaller.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Finding applications…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(uninstaller.filteredApps, selection: $uninstaller.selectedApp) { app in
                    HStack(spacing: 10) {
                        AppIconView(path: app.url.path)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .lineLimit(1)
                            Text(Format.bytes(app.size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(app)
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let app = uninstaller.selectedApp {
            AppDetailView(app: app, confirmingUninstall: $confirmingUninstall)
        } else {
            VStack(spacing: 12) {
                IconBadge(systemName: "app.badge.checkmark", tint: .red, size: 64)
                Text(uninstaller.lastUninstalled.map { "\($0) was moved to the Trash" }
                     ?? "Select an app to see its leftover files")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("\(uninstaller.apps.count) apps found")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct AppDetailView: View {
    @Environment(UninstallerModel.self) private var uninstaller
    let app: AppInfo
    @Binding var confirmingUninstall: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            leftoverList
            Divider()
            footer
        }
        .task(id: app.id) {
            await uninstaller.loadLeftovers(for: app)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconView(path: app.url.path, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.title3.weight(.semibold))
                Text(app.bundleID ?? app.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.bytes(app.size))
                .font(.title3.weight(.medium).monospacedDigit())
        }
        .padding(16)
    }

    @ViewBuilder
    private var leftoverList: some View {
        if uninstaller.isLoadingLeftovers {
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching for leftovers…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if uninstaller.leftovers.isEmpty {
            Text("No leftover files found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(uninstaller.leftovers) { leftover in
                LeftoverRow(leftover: leftover)
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack {
            if !uninstaller.failures.isEmpty {
                Label("\(uninstaller.failures.count) items failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Text("App + \(Format.bytes(uninstaller.leftoversSize)) of leftovers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                confirmingUninstall = true
            } label: {
                if uninstaller.isUninstalling {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 90)
                } else {
                    Text("Uninstall")
                        .frame(minWidth: 90)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(uninstaller.isUninstalling)
        }
        .padding(16)
    }
}

private struct LeftoverRow: View {
    @Environment(UninstallerModel.self) private var uninstaller
    let leftover: LeftoverItem

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Select \(leftover.url.lastPathComponent)", isOn: selectionBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 1) {
                Text(leftover.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(leftover.kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.bytes(leftover.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.revealInFinder(leftover.url)
            }
        }
    }

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { leftover.isSelected },
            set: { uninstaller.setLeftover(leftover.id, selected: $0) }
        )
    }
}
