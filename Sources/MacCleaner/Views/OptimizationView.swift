import SwiftUI

struct OptimizationView: View {
    @Environment(OptimizationModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heavyConsumers
                launchAgents
            }
            .padding(24)
        }
        .navigationTitle("Optimization")
        .task { await model.monitorProcesses() }
        .task { await model.loadAgents() }
    }

    // MARK: - Heavy consumers

    private var heavyConsumers: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Heavy Consumers", systemImage: "gauge.with.needle")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("Sort by", selection: $model.processSort) {
                    ForEach(OptimizationModel.ProcessSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            VStack(spacing: 0) {
                if model.sortedProcesses.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(24)
                } else {
                    ForEach(model.sortedProcesses) { process in
                        ProcessRow(process: process)
                        if process.id != model.sortedProcesses.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Launch agents

    private var launchAgents: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Login Items (Launch Agents)", systemImage: "power")
                .font(.title3.weight(.semibold))
            Text("Background helpers that start automatically when you log in. Disabling renames the agent and unloads it; you can re-enable any time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let error = model.agentError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            VStack(spacing: 0) {
                if model.agents.isEmpty {
                    Text("No user launch agents found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                } else {
                    ForEach(model.agents) { agent in
                        LaunchAgentRow(agent: agent)
                        if agent.id != model.agents.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
        }
    }
}

private struct ProcessRow: View {
    @Environment(OptimizationModel.self) private var model
    let process: RunningProcessInfo

    var body: some View {
        HStack(spacing: 12) {
            Text(process.name)
                .lineLimit(1)
                .frame(minWidth: 140, alignment: .leading)
            Spacer()
            Text(process.cpuPercent, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
                .foregroundStyle(process.cpuPercent > 50 ? .orange : .secondary)
            Text("% CPU")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(Format.bytes(process.memoryBytes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Button("Quit") {
                Task { await model.quit(process) }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

private struct LaunchAgentRow: View {
    @Environment(OptimizationModel.self) private var model
    let agent: LaunchAgent

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.label)
                    .lineLimit(1)
                Text(agent.program)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if model.busyAgentIDs.contains(agent.id) {
                ProgressView()
                    .controlSize(.small)
            } else {
                Toggle("Enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.revealInFinder(agent.url)
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { agent.isEnabled },
            set: { enabled in Task { await model.setAgent(agent, enabled: enabled) } }
        )
    }
}
