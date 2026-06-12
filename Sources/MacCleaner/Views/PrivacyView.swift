import SwiftUI

struct PrivacyView: View {
    @Environment(PrivacyModel.self) private var model

    var body: some View {
        Group {
            if model.isScanning {
                scanningState
            } else if !model.hasScanned {
                emptyState
            } else {
                results
            }
        }
        .navigationTitle("Privacy")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBadge(systemName: "hand.raised", tint: .cyan, size: 64)
            Text("Clear browser caches, history and cookies")
                .font(.title3)
                .foregroundStyle(.secondary)
            BigActionButton(title: "Scan", tint: .cyan) {
                Task { await model.scan() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Looking through browser data…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var results: some View {
        if model.browsers.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("No browser data found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                List {
                    ForEach(model.browsers) { browser in
                        BrowserSection(browser: browser)
                    }
                    if !model.failures.isEmpty {
                        FailureList(failures: model.failures)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.inset)
                Divider()
                footer
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.cleanableSelectedCount) items selected")
                    .font(.subheadline.weight(.medium))
                if model.lastFreed > 0 {
                    Text("Last clean freed \(Format.bytes(model.lastFreed))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            Button {
                Task { await model.cleanSelected() }
            } label: {
                if model.isCleaning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 120)
                } else {
                    Text("Clean \(Format.bytes(model.cleanableSelectedSize))")
                        .frame(minWidth: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.cyan)
            .disabled(model.cleanableSelectedCount == 0 || model.isCleaning)
        }
        .padding(16)
    }
}

private struct BrowserSection: View {
    @Environment(PrivacyModel.self) private var model
    let browser: BrowserData

    var body: some View {
        DisclosureGroup {
            ForEach(browser.items) { item in
                BrowserItemRow(item: item, browserID: browser.id, disabled: browser.isRunning)
            }
        } label: {
            HStack(spacing: 10) {
                if let appPath = browser.appPath {
                    AppIconView(path: appPath, size: 30)
                } else {
                    IconBadge(systemName: "globe", tint: .cyan, size: 30)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(browser.name)
                        .font(.body.weight(.semibold))
                    if browser.isRunning {
                        Text("Running — quit to clean its data")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(browser.items.count) data locations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if browser.isRunning {
                    Button("Quit") {
                        Task { await model.quitBrowser(browser) }
                    }
                    .controlSize(.small)
                }
                Text(Format.bytes(browser.totalSize))
                    .font(.body.weight(.medium).monospacedDigit())
            }
            .padding(.vertical, 4)
        }
    }
}

private struct BrowserItemRow: View {
    @Environment(PrivacyModel.self) private var model
    let item: BrowserDataItem
    let browserID: String
    let disabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Select \(item.kind)", isOn: selectionBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(disabled)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.kind)
                Text(item.url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(Format.bytes(item.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 24)
        .opacity(disabled ? 0.5 : 1)
    }

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { item.isSelected },
            set: { model.setItem(item.id, inBrowser: browserID, selected: $0) }
        )
    }
}
