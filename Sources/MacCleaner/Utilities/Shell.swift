import Foundation

struct ShellResult: Sendable {
    let status: Int32
    let output: String
    var succeeded: Bool { status == 0 }
}

enum Shell {
    static func run(_ launchPath: String, _ arguments: [String]) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ShellResult(
                        status: process.terminationStatus,
                        output: output.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                } catch {
                    continuation.resume(returning: ShellResult(status: -1, output: error.localizedDescription))
                }
            }
        }
    }

    static func zsh(_ command: String) async -> ShellResult {
        await run("/bin/zsh", ["-c", command])
    }

    /// Runs a command with admin privileges via the system authorization dialog.
    static func admin(_ command: String) async -> ShellResult {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return await run(
            "/usr/bin/osascript",
            ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        )
    }
}
