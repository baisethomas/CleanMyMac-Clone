import SwiftUI

struct MaintenanceView: View {
    @Environment(MaintenanceModel.self) private var maintenance

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("One-click tasks to keep your Mac fast and healthy. Tasks marked with a lock ask for your administrator password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(maintenance.tasks) { task in
                        MaintenanceCard(task: task)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Maintenance")
    }
}

private struct MaintenanceCard: View {
    @Environment(MaintenanceModel.self) private var maintenance
    let task: MaintenanceTask

    private var isRunning: Bool { maintenance.runningTaskIDs.contains(task.id) }
    private var outcome: MaintenanceModel.TaskOutcome? { maintenance.outcomes[task.id] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: task.icon, tint: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(task.name)
                            .font(.headline)
                        if task.needsAdmin {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            Text(task.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack {
                if let outcome {
                    Label {
                        Text(outcome.message)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } icon: {
                        Image(systemName: outcome.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(outcome.succeeded ? .green : .red)
                }
                Spacer()
                Button {
                    Task { await maintenance.run(task) }
                } label: {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 50)
                    } else {
                        Text("Run")
                            .frame(minWidth: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isRunning)
            }
        }
        .padding(16)
        .frame(minHeight: 140, alignment: .top)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
    }
}
