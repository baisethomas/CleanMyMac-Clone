import Foundation

enum Format {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func relativeDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
