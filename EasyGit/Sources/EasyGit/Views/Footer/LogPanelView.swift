import SwiftUI

struct LogPanelView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var commandText = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1

    private var logStore: LogStore { appVM.logStore }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with drag handle
            HStack {
                Text("Terminal")
                    .font(Theme.uiFontMedium)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Button {
                    logStore.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDimmed)
                }
                .buttonStyle(.plain)
                .help("Clear log")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        logStore.isShowingPanel = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textDimmed)
                }
                .buttonStyle(.plain)
                .help("Close terminal")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.panelHeaderBG)

            Divider().background(Theme.borderColor)

            // Log content — single selectable text block
            ScrollViewReader { proxy in
                ScrollView {
                    buildLogText()
                        .font(Theme.monoFont)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logBottom")
                }
                .onChange(of: logStore.entries.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }

            Divider().background(Theme.borderColor)

            // Command input
            HStack(spacing: 6) {
                Text(promptLabel)
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)

                TextField("Type a command...", text: $commandText)
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.textPrimary)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        runCommand()
                    }
                    .onKeyPress(.upArrow) {
                        navigateHistory(direction: .up)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        navigateHistory(direction: .down)
                        return .handled
                    }
                    .disabled(logStore.isRunningCommand)

                if logStore.isRunningCommand {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.diffBG)
        }
        .background(Theme.diffBG)
    }

    private var promptLabel: String {
        if let repo = appVM.selectedRepo {
            let name = URL(fileURLWithPath: repo.path).lastPathComponent
            return "\(name) $"
        }
        return "$"
    }

    private enum HistoryDirection { case up, down }

    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        switch direction {
        case .up:
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
            }
        case .down:
            if historyIndex > 0 {
                historyIndex -= 1
            } else {
                historyIndex = -1
                commandText = ""
                return
            }
        }
        commandText = commandHistory[historyIndex]
    }

    private func runCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        commandHistory.insert(cmd, at: 0)
        historyIndex = -1
        commandText = ""

        let workDir = appVM.selectedRepo?.path ?? FileManager.default.currentDirectoryPath

        Task {
            await logStore.executeCommand(cmd, workingDirectory: workDir)
            // Refresh repo state after command
            if appVM.selectedRepo != nil {
                await appVM.loadRepoInfo()
                NotificationCenter.default.post(name: .gitFilesChanged, object: nil)
            }
        }
    }

    private func buildLogText() -> Text {
        let entries = logStore.entries
        guard !entries.isEmpty else {
            return Text("Type a command below or use the app buttons")
                .foregroundColor(Theme.textDimmed)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        var result = Text("")
        for (index, entry) in entries.enumerated() {
            let time = formatter.string(from: entry.timestamp)
            let timeText = Text(time + "  ")
                .foregroundColor(Theme.textDimmed)
            let bodyText = Text(entry.text)
                .foregroundColor(textColor(for: entry.kind))

            if index > 0 {
                result = result + Text("\n")
            }
            result = result + timeText + bodyText
        }
        return result
    }

    private func textColor(for kind: LogStore.LogEntry.Kind) -> Color {
        switch kind {
        case .command: return Theme.primary
        case .stdout: return Theme.textSecondary
        case .stderr: return Theme.diffRemoveText
        case .info: return Theme.diffAddText
        }
    }
}
