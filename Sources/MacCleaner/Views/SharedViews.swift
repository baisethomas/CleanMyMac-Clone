import SwiftUI

extension CategoryTint {
    var color: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .orange: .orange
        case .red: .red
        case .green: .green
        case .teal: .teal
        case .pink: .pink
        case .yellow: .yellow
        }
    }
}

/// Rounded icon badge used in category and task rows.
struct IconBadge: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.28))
    }
}

/// Horizontal usage bar with a label, used in the stats footer.
struct StatTile: View {
    let title: String
    let icon: String
    let tint: Color
    let fraction: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            ProgressView(value: min(max(fraction, 0), 1))
                .tint(tint)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }
}

/// Footer with live disk / memory / CPU stats.
struct StatsFooter: View {
    @Environment(StatsModel.self) private var stats

    var body: some View {
        HStack(spacing: 12) {
            StatTile(
                title: "Storage",
                icon: "internaldrive.fill",
                tint: .blue,
                fraction: stats.disk?.usedFraction ?? 0,
                caption: diskCaption
            )
            StatTile(
                title: "Memory",
                icon: "memorychip.fill",
                tint: .purple,
                fraction: stats.memory?.usedFraction ?? 0,
                caption: memoryCaption
            )
            StatTile(
                title: "CPU",
                icon: "cpu.fill",
                tint: .orange,
                fraction: stats.cpuPercent / 100,
                caption: cpuCaption
            )
        }
    }

    private var diskCaption: String {
        guard let disk = stats.disk else { return "—" }
        return "\(Format.bytes(disk.free)) free of \(Format.bytes(disk.total))"
    }

    private var memoryCaption: String {
        guard let memory = stats.memory else { return "—" }
        return "\(Format.bytes(memory.used)) of \(Format.bytes(memory.total)) used"
    }

    private var cpuCaption: String {
        "\(Int(stats.cpuPercent))% load"
    }
}

/// Proportional horizontal bar for size visualizations.
struct SizeBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary.opacity(0.5))
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint.gradient)
                    .frame(width: max(proxy.size.width * min(max(fraction, 0), 1), 2))
            }
        }
        .frame(height: 6)
    }
}

/// App icon fetched from the system, cached per path.
struct AppIconView: View {
    let path: String
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: AppIconCache.icon(forPath: path))
            .resizable()
            .frame(width: size, height: size)
    }
}

@MainActor
enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forPath path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }
}

extension NSWorkspace {
    func revealInFinder(_ url: URL) {
        activateFileViewerSelecting([url])
    }
}
