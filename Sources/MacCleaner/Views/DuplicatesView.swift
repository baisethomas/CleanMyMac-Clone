import SwiftUI

struct DuplicatesView: View {
    @Environment(DuplicatesModel.self) private var model
    @State private var confirmingRemoval = false

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isScanning {
                scanningState
            } else if !model.hasScanned {
                emptyState
            } else {
                results
            }
        }
        .navigationTitle("Duplicates")
        .toolbar {
            ToolbarItemGroup {
                Picker("Minimum size", selection: $model.minSize) {
                    ForEach(DuplicatesModel.sizeOptions, id: \.bytes) { option in
                        Text("Over \(option.label)").tag(option.bytes)
                    }
                }
                .pickerStyle(.menu)
                Button("Scan", systemImage: "magnifyingglass") {
                    Task { await model.scan() }
                }
                .disabled(model.isScanning)
            }
        }
        .confirmationDialog(
            "Move \(model.selectedCount) duplicate files to Trash?",
            isPresented: $confirmingRemoval
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await model.removeSelected() }
            }
        } message: {
            Text("\(Format.bytes(model.selectedSize)) will be reclaimed. At least one copy of every file is kept.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBadge(systemName: "doc.on.doc", tint: .indigo, size: 64)
            Text("Find files with identical content in your home folder")
                .font(.title3)
                .foregroundStyle(.secondary)
            BigActionButton(title: "Scan", tint: .indigo) {
                Task { await model.scan() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Comparing file contents…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var results: some View {
        if model.groups.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("No duplicates found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                List {
                    ForEach(model.groups) { group in
                        DuplicateGroupSection(group: group)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.groups.count) duplicate sets · \(Format.bytes(model.totalWasted)) wasted")
                    .font(.subheadline.weight(.medium))
                Text("\(model.selectedCount) copies selected (\(Format.bytes(model.selectedSize)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Keep Newest") { model.keepNewestEverywhere() }
            Button("Keep Oldest") { model.keepOldestEverywhere() }
            Button("Remove Duplicates") {
                confirmingRemoval = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(model.selectedCount == 0 || model.isCleaning)
        }
        .padding(16)
    }
}

private struct DuplicateGroupSection: View {
    @Environment(DuplicatesModel.self) private var model
    let group: DuplicateGroup

    var body: some View {
        DisclosureGroup {
            ForEach(group.files) { file in
                DuplicateFileRow(file: file, groupID: group.id)
            }
        } label: {
            HStack(spacing: 10) {
                IconBadge(systemName: "doc.on.doc", tint: .indigo, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.files.first?.name ?? "Duplicate set")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("\(group.files.count) copies · \(Format.bytes(group.fileSize)) each")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Format.bytes(group.wastedSize)) wasted")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct DuplicateFileRow: View {
    @Environment(DuplicatesModel.self) private var model
    let file: DuplicateFile
    let groupID: String

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Select \(file.name)", isOn: selectionBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 1) {
                Text(file.url.deletingLastPathComponent().path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Modified \(Format.relativeDate(file.modified))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !file.isSelected {
                Text("KEEP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.15), in: .capsule)
            }
        }
        .padding(.leading, 24)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.revealInFinder(file.url)
            }
        }
    }

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { file.isSelected },
            set: { model.setFile(file.id, inGroup: groupID, selected: $0) }
        )
    }
}
