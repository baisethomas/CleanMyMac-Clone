import SwiftUI

struct SystemJunkView: View {
    @Environment(JunkModel.self) private var junk

    var body: some View {
        Group {
            switch junk.phase {
            case .idle, .finished:
                emptyState
            case .scanning:
                scanningState
            case .reviewing, .cleaning:
                reviewState
            }
        }
        .navigationTitle("System Junk")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBadge(systemName: "paintbrush", tint: .blue, size: 64)
            Text("Find caches, logs and other junk files")
                .font(.title3)
                .foregroundStyle(.secondary)
            if junk.phase == .finished {
                Text("Last cleanup freed \(Format.bytes(junk.lastFreed))")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            BigActionButton(title: "Scan", tint: .blue) {
                Task { await junk.scan() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 16) {
            ProgressView(value: junk.scanProgress)
                .frame(maxWidth: 320)
            Text("Scanning \(junk.currentScanTarget)…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewState: some View {
        VStack(spacing: 0) {
            List {
                ForEach(junk.categories) { category in
                    JunkCategorySection(category: category)
                }
                if !junk.failures.isEmpty {
                    FailureList(failures: junk.failures)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.inset)
            Divider()
            cleanBar
        }
    }

    private var cleanBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(junk.selectedCount) items selected")
                    .font(.subheadline.weight(.medium))
                Text(Format.bytes(junk.selectedSize))
                    .font(.title3.weight(.bold).monospacedDigit())
            }
            Spacer()
            Toggle("Move to Trash instead of deleting", isOn: moveToTrashBinding)
                .toggleStyle(.checkbox)
                .font(.subheadline)
            Button {
                Task { await junk.clean() }
            } label: {
                if junk.phase == .cleaning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 120)
                } else {
                    Text("Clean \(Format.bytes(junk.selectedSize))")
                        .frame(minWidth: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .disabled(junk.selectedCount == 0 || junk.phase == .cleaning)
        }
        .padding(16)
    }

    private var moveToTrashBinding: Binding<Bool> {
        Binding(
            get: { junk.moveToTrash },
            set: { junk.moveToTrash = $0 }
        )
    }
}

private struct JunkCategorySection: View {
    @Environment(JunkModel.self) private var junk
    let category: JunkCategory

    var body: some View {
        DisclosureGroup {
            ForEach(category.items) { item in
                JunkItemRow(item: item, categoryID: category.id, tint: category.tint.color)
            }
        } label: {
            HStack(spacing: 10) {
                Toggle("Select \(category.name)", isOn: categoryBinding)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                IconBadge(systemName: category.icon, tint: category.tint.color, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(category.name)
                            .font(.body.weight(.semibold))
                        SafetyBadge(safety: category.safety)
                    }
                    Text(category.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Format.bytes(category.totalSize))
                    .font(.body.weight(.medium).monospacedDigit())
            }
            .padding(.vertical, 4)
        }
    }

    private var categoryBinding: Binding<Bool> {
        Binding(
            get: { category.allSelected },
            set: { junk.setCategory(category.id, selected: $0) }
        )
    }
}

private struct SafetyBadge: View {
    let safety: SafetyLevel

    var body: some View {
        Text(safety == .safe ? "SAFE" : "REVIEW")
            .font(.caption2.weight(.bold))
            .foregroundStyle(safety == .safe ? .green : .orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                (safety == .safe ? Color.green : Color.orange).opacity(0.15),
                in: .capsule
            )
    }
}

private struct JunkItemRow: View {
    @Environment(JunkModel.self) private var junk
    let item: CleanableItem
    let categoryID: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Select \(item.name)", isOn: itemBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(Format.bytes(item.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 24)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.revealInFinder(item.url)
            }
        }
    }

    private var itemBinding: Binding<Bool> {
        Binding(
            get: { item.isSelected },
            set: { junk.setItem(item.id, inCategory: categoryID, selected: $0) }
        )
    }
}
