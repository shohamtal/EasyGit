import SwiftUI

struct FooterView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(ChangesViewModel.self) private var changesVM: ChangesViewModel?

    private var logStore: LogStore { appVM.logStore }

    var body: some View {
        HStack(spacing: 12) {
            // Connection status
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Ready")
                    .font(Theme.smallFont)
                    .foregroundStyle(Theme.textTertiary)
            }

            Divider()
                .frame(height: 10)

            // Status message — clickable to toggle log panel
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    logStore.isShowingPanel.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    if appVM.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.6)
                    }
                    Text(appVM.statusMessage)
                        .font(Theme.smallFont)
                        .foregroundStyle(statusColor)
                    Image(systemName: logStore.isShowingPanel ? "chevron.down" : "chevron.up")
                        .font(.system(size: 7))
                        .foregroundStyle(Theme.textDimmed)
                }
            }
            .buttonStyle(.plain)
            .help("Toggle output log")

            Spacer()

            if let changesVM {
                HStack(spacing: 8) {
                    Text("Unstaged: \(changesVM.unstagedFiles.count)")
                        .font(Theme.smallFont)
                        .foregroundStyle(Theme.textTertiary)

                    Text("Staged: \(changesVM.stagedFiles.count)")
                        .font(Theme.smallFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Text("UTF-8")
                .font(Theme.smallFont)
                .foregroundStyle(Theme.textDimmed)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.footerHeight)
        .background(Theme.sidebarBG)
    }

    private var statusColor: Color {
        let msg = appVM.statusMessage
        if msg.contains("failed") { return Theme.diffRemoveText }
        if msg.contains("complete") || msg.contains("Rescanned") { return Theme.diffAddText }
        if appVM.isLoading { return Theme.primary }
        return Theme.textTertiary
    }
}
