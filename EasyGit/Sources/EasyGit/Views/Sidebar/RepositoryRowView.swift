import SwiftUI

struct RepositoryRowView: View {
    @Environment(AppViewModel.self) private var appVM
    let repo: Repository
    var indented: Bool = false

    private var isSelected: Bool {
        appVM.selectedRepo?.id == repo.id
    }

    var body: some View {
        Button {
            appVM.selectRepo(repo)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.textDimmed)

                Text(repo.name)
                    .font(Theme.uiFont)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, indented ? 30 : 12)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? Theme.primary.opacity(0.2)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Remove") {
                appVM.removeRepository(repo)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
            }
        }
    }
}
