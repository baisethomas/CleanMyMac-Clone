import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @State private var undoFailures: [String] = []
    @State private var showingUndoResult = false
    @State private var lastRestoredCount = 0

    var body: some View {
        Group {
            if history.events.isEmpty {
                emptyState
            } else {
                eventList
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !history.events.isEmpty {
                Button("Clear History", systemImage: "xmark.circle") {
                    history.clearHistory()
                }
            }
        }
        .alert("Restore finished", isPresented: $showingUndoResult) {
            Button("OK") {}
        } message: {
            Text(undoResultMessage)
        }
    }

    private var undoResultMessage: String {
        var message = "\(lastRestoredCount) items were restored from the Trash."
        if !undoFailures.isEmpty {
            message += "\n\nNot restored:\n" + undoFailures.prefix(5).joined(separator: "\n")
        }
        return message
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBadge(systemName: "clock.arrow.circlepath", tint: .gray, size: 64)
            Text("Cleanups you run will appear here")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventList: some View {
        List {
            Section {
                HStack {
                    IconBadge(systemName: "sparkles", tint: .green, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Format.bytes(history.totalCleaned))
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("cleaned in total across \(history.events.count) cleanups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            Section("Cleanups") {
                ForEach(history.events) { event in
                    HistoryEventRow(event: event) { result in
                        lastRestoredCount = result.restoredCount
                        undoFailures = result.failures
                        showingUndoResult = true
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

private struct HistoryEventRow: View {
    @Environment(HistoryStore.self) private var history
    let event: CleanEvent
    let onUndoFinished: (RestoreResult) -> Void
    @State private var isRestoring = false

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: icon, tint: .blue, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.source)
                    .font(.body.weight(.medium))
                Text("\(event.files.count) items · \(event.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.bytes(event.totalSize))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            if event.undone {
                Text("RESTORED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
            } else if event.movedToTrash {
                Button {
                    isRestoring = true
                    Task {
                        let result = await history.undo(event)
                        isRestoring = false
                        onUndoFinished(result)
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Restore")
                    }
                }
                .controlSize(.small)
                .disabled(isRestoring)
                .help("Move these items back out of the Trash")
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch event.source {
        case "System Junk": "paintbrush"
        case "Large & Old Files": "doc.zipper"
        case "Uninstaller": "app.badge.checkmark"
        case "Duplicates": "doc.on.doc"
        case "Privacy": "hand.raised"
        default: "sparkles"
        }
    }
}
