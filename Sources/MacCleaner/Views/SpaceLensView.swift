import SwiftUI

struct SpaceLensView: View {
    enum ViewMode: String, CaseIterable {
        case treemap = "Treemap"
        case list = "List"
    }

    @Environment(SpaceLensModel.self) private var model
    @State private var mode: ViewMode = .treemap

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbs
            Divider()
            content
        }
        .navigationTitle("Space Lens")
        .toolbar {
            Picker("View", selection: $mode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .task {
            if !model.hasScanned {
                await model.load()
            }
        }
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(Array(model.pathStack.enumerated()), id: \.offset) { index, url in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        Task { await model.jump(to: index) }
                    } label: {
                        Text(index == 0 ? "Home" : url.lastPathComponent)
                            .font(.subheadline.weight(index == model.pathStack.count - 1 ? .semibold : .regular))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == model.pathStack.count - 1 ? .primary : Color.accentColor)
                }
                Spacer()
                Text(Format.bytes(model.totalSize))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Measuring \(model.currentURL.lastPathComponent)…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.entries.isEmpty {
            Text("Nothing measurable in this folder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if mode == .treemap {
            TreemapView(entries: model.entries) { entry in
                Task { await model.open(entry) }
            }
        } else {
            entryList
        }
    }

    private var entryList: some View {
        List(model.entries) { entry in
            SpaceLensRow(entry: entry, maxSize: model.entries.first?.size ?? 1)
        }
        .listStyle(.inset)
    }
}

private struct SpaceLensRow: View {
    @Environment(SpaceLensModel.self) private var model
    let entry: FolderEntry
    let maxSize: Int64

    var body: some View {
        Button {
            Task { await model.open(entry) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(Format.bytes(entry.size))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    SizeBar(
                        fraction: maxSize > 0 ? Double(entry.size) / Double(maxSize) : 0,
                        tint: entry.isDirectory ? .blue : .teal
                    )
                }
                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.revealInFinder(entry.url)
            }
        }
    }
}
