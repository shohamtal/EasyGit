import Foundation

@Observable
final class LogStore: @unchecked Sendable {
    var entries: [LogEntry] = []
    var isShowingPanel = false
    var isRunningCommand = false

    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let text: String
        let kind: Kind

        enum Kind: Sendable {
            case command
            case stdout
            case stderr
            case info
        }
    }

    func append(_ text: String, kind: LogEntry.Kind) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.append(LogEntry(timestamp: Date(), text: trimmed, kind: kind))
    }

    func clear() {
        entries.removeAll()
    }

    func appendFromBackground(_ text: String, kind: LogEntry.Kind) {
        Task { @MainActor [weak self] in
            self?.append(text, kind: kind)
        }
    }

    /// Execute a shell command in the given working directory
    func executeCommand(_ command: String, workingDirectory: String) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await MainActor.run {
            self.append("$ \(trimmed)", kind: .command)
            self.isRunningCommand = true
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", trimmed]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()

            // Read output in background
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            await MainActor.run {
                if !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.append(stdout.trimmingCharacters(in: .whitespacesAndNewlines), kind: .stdout)
                }
                if !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.append(stderr.trimmingCharacters(in: .whitespacesAndNewlines), kind: .stderr)
                }
                if process.terminationStatus != 0 {
                    self.append("Exit code: \(process.terminationStatus)", kind: .stderr)
                }
                self.isRunningCommand = false
            }
        } catch {
            await MainActor.run {
                self.append("Failed to run command: \(error.localizedDescription)", kind: .stderr)
                self.isRunningCommand = false
            }
        }
    }
}
