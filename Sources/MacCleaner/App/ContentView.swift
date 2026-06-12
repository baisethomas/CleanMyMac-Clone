import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case smartScan
    case systemJunk
    case privacy
    case maintenance
    case optimization
    case uninstaller
    case largeFiles
    case duplicates
    case spaceLens
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartScan: "Smart Scan"
        case .systemJunk: "System Junk"
        case .privacy: "Privacy"
        case .maintenance: "Maintenance"
        case .optimization: "Optimization"
        case .uninstaller: "Uninstaller"
        case .largeFiles: "Large & Old Files"
        case .duplicates: "Duplicates"
        case .spaceLens: "Space Lens"
        case .history: "History"
        }
    }

    var icon: String {
        switch self {
        case .smartScan: "sparkles"
        case .systemJunk: "paintbrush"
        case .privacy: "hand.raised"
        case .maintenance: "wrench.and.screwdriver"
        case .optimization: "gauge.with.needle"
        case .uninstaller: "app.badge.checkmark"
        case .largeFiles: "doc.zipper"
        case .duplicates: "doc.on.doc"
        case .spaceLens: "circle.hexagongrid"
        case .history: "clock.arrow.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .smartScan: .purple
        case .systemJunk: .blue
        case .privacy: .cyan
        case .maintenance: .orange
        case .optimization: .mint
        case .uninstaller: .red
        case .largeFiles: .teal
        case .duplicates: .indigo
        case .spaceLens: .green
        case .history: .gray
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem = .smartScan
    @Environment(StatsModel.self) private var stats

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .task { await stats.monitor() }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                sidebarRow(.smartScan)
            }
            Section("Cleanup") {
                sidebarRow(.systemJunk)
                sidebarRow(.privacy)
            }
            Section("Speed") {
                sidebarRow(.maintenance)
                sidebarRow(.optimization)
            }
            Section("Applications") {
                sidebarRow(.uninstaller)
            }
            Section("Files") {
                sidebarRow(.largeFiles)
                sidebarRow(.duplicates)
                sidebarRow(.spaceLens)
            }
            Section("Activity") {
                sidebarRow(.history)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .navigationTitle("MacCleaner")
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label {
            Text(item.title)
        } icon: {
            Image(systemName: item.icon)
                .foregroundStyle(item.tint)
        }
        .tag(item)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .smartScan: SmartScanView()
        case .systemJunk: SystemJunkView()
        case .privacy: PrivacyView()
        case .maintenance: MaintenanceView()
        case .optimization: OptimizationView()
        case .uninstaller: UninstallerView()
        case .largeFiles: LargeFilesView()
        case .duplicates: DuplicatesView()
        case .spaceLens: SpaceLensView()
        case .history: HistoryView()
        }
    }
}
