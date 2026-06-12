import SwiftUI

struct SmartScanView: View {
    @Environment(JunkModel.self) private var junk
    @State private var hasFullDiskAccess = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    if !hasFullDiskAccess {
                        FullDiskAccessBanner {
                            hasFullDiskAccess = FullDiskAccess.hasAccess()
                        }
                    }
                    hero
                    if junk.phase == .reviewing {
                        breakdown
                    }
                    if !junk.failures.isEmpty {
                        FailureList(failures: junk.failures)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            Divider()
            StatsFooter()
                .padding(16)
        }
        .navigationTitle("Smart Scan")
        .onAppear {
            hasFullDiskAccess = FullDiskAccess.hasAccess()
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: 20) {
            ScanRing(phase: junk.phase, progress: junk.scanProgress)
            heroText
            heroButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.25), .blue.opacity(0.15), .clear],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: .rect(cornerRadius: 20)
        )
    }

    @ViewBuilder
    private var heroText: some View {
        switch junk.phase {
        case .idle:
            Text("Scan your Mac for junk, logs and caches")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .scanning:
            Text("Scanning \(junk.currentScanTarget)…")
                .font(.title3)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        case .reviewing:
            VStack(spacing: 4) {
                Text(Format.bytes(junk.totalFound))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("of junk found — \(Format.bytes(junk.selectedSize)) selected for cleanup")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        case .cleaning:
            Text("Cleaning…")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .finished:
            VStack(spacing: 4) {
                Text(Format.bytes(junk.lastFreed))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text(junk.moveToTrash ? "moved to Trash" : "permanently removed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var heroButton: some View {
        switch junk.phase {
        case .idle:
            BigActionButton(title: "Scan", tint: .purple) {
                Task { await junk.scan() }
            }
        case .scanning, .cleaning:
            BigActionButton(title: "Working…", tint: .gray, disabled: true) {}
        case .reviewing:
            HStack(spacing: 12) {
                BigActionButton(title: "Clean \(Format.bytes(junk.selectedSize))", tint: .green) {
                    Task { await junk.clean() }
                }
                .disabled(junk.selectedCount == 0)
                Button("Rescan") {
                    Task { await junk.scan() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        case .finished:
            BigActionButton(title: "Scan Again", tint: .purple) {
                junk.reset()
                Task { await junk.scan() }
            }
        }
    }

    // MARK: - Breakdown

    private var breakdown: some View {
        VStack(spacing: 0) {
            ForEach(junk.categories) { category in
                SmartScanCategoryRow(category: category)
                if category.id != junk.categories.last?.id {
                    Divider()
                }
            }
        }
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
    }
}

// MARK: - Components

private struct SmartScanCategoryRow: View {
    @Environment(JunkModel.self) private var junk
    let category: JunkCategory

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Select \(category.name)", isOn: categoryBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
            IconBadge(systemName: category.icon, tint: category.tint.color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body.weight(.medium))
                Text("\(category.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.bytes(category.totalSize))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var categoryBinding: Binding<Bool> {
        Binding(
            get: { category.allSelected },
            set: { junk.setCategory(category.id, selected: $0) }
        )
    }
}

struct ScanRing: View {
    let phase: JunkModel.Phase
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: ringFraction)
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: ringFraction)
            Image(systemName: centerSymbol)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(centerColor)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 150, height: 150)
    }

    private var ringFraction: Double {
        switch phase {
        case .idle: 0
        case .scanning: max(progress, 0.03)
        case .reviewing, .cleaning: 1
        case .finished: 1
        }
    }

    private var centerSymbol: String {
        switch phase {
        case .idle: "sparkles"
        case .scanning, .cleaning: "magnifyingglass"
        case .reviewing: "tray.full"
        case .finished: "checkmark.circle.fill"
        }
    }

    private var centerColor: Color {
        phase == .finished ? .green : .purple
    }
}

struct BigActionButton: View {
    let title: String
    let tint: Color
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(minWidth: 160)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tint)
        .disabled(disabled)
    }
}

struct FullDiskAccessBanner: View {
    let onRecheck: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Disk Access is off")
                    .font(.subheadline.weight(.semibold))
                Text("Some caches, Mail attachments and browser data can't be scanned without it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open System Settings") {
                FullDiskAccess.openSystemSettings()
            }
            Button("Recheck", action: onRecheck)
        }
        .padding(14)
        .background(.blue.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}

struct FailureList: View {
    let failures: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(failures.count) items could not be removed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(failures.prefix(5), id: \.self) { failure in
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 10))
    }
}
