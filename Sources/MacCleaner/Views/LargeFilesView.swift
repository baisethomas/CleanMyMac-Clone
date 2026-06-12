import SwiftUI

struct LargeFilesView: View {
    @Environment(LargeFilesModel.self) private var model
    @State private var confirmingRemoval = false

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isScanning {
                scanningState
            } else if !model.hasScanned {
                emptyState
            } else {
                resultsTable
            }
        }
        .navigationTitle("Large & Old Files")
        .toolbar {
            ToolbarItemGroup {
                Picker("Minimum size", selection: $model.minSize) {
                    ForEach(LargeFilesModel.sizeOptions, id: \.bytes) { option in
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
            "Move \(model.selection.count) files to Trash?",
            isPresented: $confirmingRemoval
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await model.removeSelected() }
            }
        } message: {
            Text("\(Format.bytes(model.selectedSize)) will be moved to the Trash.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBadge(systemName: "doc.zipper", tint: .teal, size: 64)
            Text("Find the biggest files in your home folder")
                .font(.title3)
                .foregroundStyle(.secondary)
            BigActionButton(title: "Scan", tint: .teal) {
                Task { await model.scan() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Scanning your home folder…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var resultsTable: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Table(model.files, selection: $model.selection) {
                TableColumn("Name") { file in
                    Text(file.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(file.url.path)
                }
                TableColumn("Size") { file in
                    Text(Format.bytes(file.size))
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 100)
                TableColumn("Last Accessed") { file in
                    Text(Format.relativeDate(file.lastAccessed))
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 130)
                TableColumn("Location") { file in
                    Text(file.url.deletingLastPathComponent().path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let id = ids.first, let file = model.files.first(where: { $0.id == id }) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.revealInFinder(file.url)
                    }
                }
            }
            Divider()
            footer
        }
    }

    private var footer: some View {
        HStack {
            if model.files.isEmpty {
                Text("No files over the size threshold were found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(model.files.count) files · \(model.selection.count) selected (\(Format.bytes(model.selectedSize)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if model.lastFreed > 0 {
                Text("· freed \(Format.bytes(model.lastFreed))")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            Spacer()
            Button("Move to Trash") {
                confirmingRemoval = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(model.selection.isEmpty)
        }
        .padding(12)
    }
}
