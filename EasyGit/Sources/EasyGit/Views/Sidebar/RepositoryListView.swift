import SwiftUI
import UniformTypeIdentifiers

struct RepositoryListView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var searchText = ""

    private var filteredRepos: [Repository] {
        if searchText.isEmpty {
            return appVM.repositories
        }
        return appVM.repositories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredUngrouped: [Repository] {
        filteredRepos.filter { $0.groupID == nil }
    }

    private func filteredRepos(in group: RepositoryGroup) -> [Repository] {
        filteredRepos.filter { $0.groupID == group.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                TextField("Search repositories", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(Theme.uiFont)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.subtleBG)

            Divider().background(Theme.borderColor)

            // Repo list
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Grouped repos
                    ForEach(appVM.groups) { group in
                        let groupRepos = filteredRepos(in: group)
                        if !groupRepos.isEmpty || searchText.isEmpty {
                            GroupRowView(group: group, repos: groupRepos)
                        }
                    }

                    // Ungrouped repos
                    ForEach(filteredUngrouped) { repo in
                        RepositoryRowView(repo: repo)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            Divider().background(Theme.borderColor)

            // Bottom: Add button
            HStack(spacing: 4) {
                Button {
                    addRepo()
                } label: {
                    Label("Add Repo", systemImage: "plus")
                        .font(Theme.uiFont)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(8)

                Spacer()
            }
        }
    }

    private func addRepo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, UTType(filenameExtension: "code-workspace") ?? .json]
        panel.message = "Select a git repo, parent directory, or .code-workspace file"
        panel.prompt = "Add"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await appVM.smartAdd(url: url)
            }
        }
    }
}

// MARK: - Group row with expand/collapse, rescan, and rename

struct GroupRowView: View {
    @Environment(AppViewModel.self) private var appVM
    let group: RepositoryGroup
    let repos: [Repository]
    @State private var isExpanded = true
    @State private var isRescanning = false
    @State private var isRenaming = false
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textDimmed)
                    .frame(width: 12)

                Image(systemName: group.workspacePath != nil ? "square.stack.3d.up.fill" : "folder.fill.badge.gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)

                if isRenaming {
                    TextField("Group name", text: $renameText, onCommit: {
                        commitRename()
                    })
                    .textFieldStyle(.plain)
                    .font(Theme.uiFontMedium)
                    .foregroundStyle(Theme.textPrimary)
                    .onExitCommand { cancelRename() }
                } else {
                    Text(group.name)
                        .font(Theme.uiFontMedium)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Text("\(repos.count)")
                    .font(Theme.smallFont)
                    .foregroundStyle(Theme.textDimmed)

                Spacer()

                // Rescan button
                if group.isRescannable {
                    Button {
                        rescan()
                    } label: {
                        if isRescanning {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textDimmed)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Rescan for repos")
                    .disabled(isRescanning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isRenaming else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }
            .contextMenu {
                Button("Rename...") {
                    startRename()
                }
                if group.isRescannable {
                    Button("Rescan") { rescan() }
                }
                if let path = group.path {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                }
                if let ws = group.workspacePath {
                    Button("Open Workspace in VS Code") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: ws))
                    }
                }
                Divider()
                Button("Remove Group") {
                    appVM.removeGroup(group)
                }
            }

            // Child repos
            if isExpanded {
                ForEach(repos) { repo in
                    RepositoryRowView(repo: repo, indented: true)
                }
            }
        }
    }

    private func rescan() {
        isRescanning = true
        Task {
            await appVM.rescanGroup(group)
            await MainActor.run { isRescanning = false }
        }
    }

    private func startRename() {
        renameText = group.name
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            appVM.renameGroup(group, to: trimmed)
        }
        isRenaming = false
    }

    private func cancelRename() {
        isRenaming = false
    }
}
