import SwiftUI

/// Compact dashboard shown from the menu bar icon.
struct MenuBarView: View {
    @Environment(StatsModel.self) private var stats
    @Environment(JunkModel.self) private var junk
    @Environment(MaintenanceModel.self) private var maintenance
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("MacCleaner")
                    .font(.headline)
                Spacer()
                Button("Open", systemImage: "macwindow") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .controlSize(.small)
            }

            gauges
            Divider()
            junkSection
            Divider()

            HStack {
                Button("Free Up RAM", systemImage: "memorychip") {
                    if let task = maintenance.tasks.first(where: { $0.id == "freeRAM" }) {
                        Task { await maintenance.run(task) }
                    }
                }
                .disabled(maintenance.runningTaskIDs.contains("freeRAM"))
                Spacer()
                Button("Quit", systemImage: "power") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 300)
        .task { await stats.monitor() }
    }

    private var gauges: some View {
        VStack(spacing: 8) {
            MenuBarGauge(
                title: "Storage",
                tint: .blue,
                fraction: stats.disk?.usedFraction ?? 0,
                caption: stats.disk.map { "\(Format.bytes($0.free)) free" } ?? "—"
            )
            MenuBarGauge(
                title: "Memory",
                tint: .purple,
                fraction: stats.memory?.usedFraction ?? 0,
                caption: stats.memory.map { "\(Format.bytes($0.used)) used" } ?? "—"
            )
            MenuBarGauge(
                title: "CPU",
                tint: .orange,
                fraction: stats.cpuPercent / 100,
                caption: "\(Int(stats.cpuPercent))%"
            )
        }
    }

    @ViewBuilder
    private var junkSection: some View {
        switch junk.phase {
        case .scanning:
            HStack(spacing: 8) {
                ProgressView(value: junk.scanProgress)
                Text("Scanning…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .reviewing:
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Format.bytes(junk.totalFound))
                        .font(.body.weight(.semibold).monospacedDigit())
                    Text("junk found — review in the app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Review") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .controlSize(.small)
            }
        default:
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Junk Scan")
                        .font(.body.weight(.medium))
                    Text(junk.lastScanDate.map { "Last scan \(Format.relativeDate($0))" }
                         ?? "No scan yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Scan Now") {
                    Task { await junk.scan() }
                }
                .controlSize(.small)
            }
        }
    }
}

private struct MenuBarGauge: View {
    let title: String
    let tint: Color
    let fraction: Double
    let caption: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .frame(width: 52, alignment: .leading)
            ProgressView(value: min(max(fraction, 0), 1))
                .tint(tint)
            Text(caption)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .trailing)
        }
    }
}
