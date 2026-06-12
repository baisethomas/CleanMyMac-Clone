import SwiftUI

/// Treemap rendering of folder entries: tile area is proportional to size.
struct TreemapView: View {
    let entries: [FolderEntry]
    let onOpen: (FolderEntry) -> Void

    private static let maxTiles = 30
    private static let palette: [Color] = [
        .blue, .purple, .indigo, .teal, .cyan, .mint, .pink, .orange,
    ]

    private struct DisplayEntry: Identifiable {
        let id: String
        let name: String
        let size: Int64
        let entry: FolderEntry?
    }

    private var displayEntries: [DisplayEntry] {
        var display = entries.prefix(Self.maxTiles).map {
            DisplayEntry(id: $0.id, name: $0.name, size: $0.size, entry: $0)
        }
        let rest = entries.dropFirst(Self.maxTiles)
        if !rest.isEmpty {
            let restSize = rest.reduce(0) { $0 + $1.size }
            display.append(DisplayEntry(
                id: "__other__",
                name: "\(rest.count) smaller items",
                size: restSize,
                entry: nil
            ))
        }
        return display
    }

    var body: some View {
        GeometryReader { proxy in
            let display = displayEntries
            let rects = TreemapLayout.layout(
                display.map { Double($0.size) },
                in: CGRect(origin: .zero, size: proxy.size)
            )
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(display, rects)), id: \.0.id) { item, rect in
                    if rect.width > 4, rect.height > 4 {
                        TreemapTile(
                            name: item.name,
                            size: item.size,
                            isDirectory: item.entry?.isDirectory ?? false,
                            color: color(for: item),
                            rect: rect
                        ) {
                            if let entry = item.entry {
                                if entry.isDirectory {
                                    onOpen(entry)
                                } else {
                                    NSWorkspace.shared.revealInFinder(entry.url)
                                }
                            }
                        }
                        .frame(width: rect.width - 2, height: rect.height - 2)
                        .offset(x: rect.minX + 1, y: rect.minY + 1)
                    }
                }
            }
        }
        .padding(16)
    }

    private func color(for item: DisplayEntry) -> Color {
        guard item.entry != nil else { return .gray }
        // Deterministic per-name hue so colors are stable across rescans.
        var hash: UInt64 = 5381
        for byte in item.name.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Self.palette[Int(hash % UInt64(Self.palette.count))]
    }
}

private struct TreemapTile: View {
    let name: String
    let size: Int64
    let isDirectory: Bool
    let color: Color
    let rect: CGRect
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.gradient)
                    .opacity(isHovered ? 1 : 0.82)
                if rect.width > 70, rect.height > 36 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(Format.bytes(size))
                            .font(.caption2)
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(6)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(name) — \(Format.bytes(size))\(isDirectory ? " (click to open)" : "")")
    }
}
