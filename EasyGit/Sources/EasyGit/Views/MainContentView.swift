import SwiftUI

struct MainContentView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var changesVM: ChangesViewModel?
    @State private var diffVM: DiffViewModel?
    @State private var commitVM: CommitViewModel?

    // Resizable panel dimensions
    @State private var sidebarWidth: CGFloat = 256
    @State private var changesPanelWidth: CGFloat = 288
    @State private var logPanelHeight: CGFloat = 220
    @State private var commitAreaHeight: CGFloat = 130

    private var logStore: LogStore { appVM.logStore }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            Divider().background(Theme.borderColor)

            HStack(spacing: 0) {
                // Panel 1: Repository List
                RepositoryListView()
                    .frame(width: sidebarWidth)
                    .background(Theme.sidebarBG)

                // Draggable divider between sidebar and changes
                draggableVDivider { delta in
                    sidebarWidth = max(150, min(400, sidebarWidth + delta))
                }

                // Panel 2: Changes
                if let changesVM {
                    ChangesPanel(unstagedRatio: Binding(
                        get: { changesVM.unstagedRatio },
                        set: { changesVM.unstagedRatio = $0 }
                    ))
                        .frame(width: changesPanelWidth)
                        .environment(changesVM)
                        .environment(diffVM!)
                } else {
                    emptyChangesPanel
                        .frame(width: changesPanelWidth)
                }

                // Draggable divider between changes and diff
                draggableVDivider { delta in
                    changesPanelWidth = max(180, min(500, changesPanelWidth + delta))
                }

                // Panel 3: Diff + Commit
                if let diffVM, let commitVM {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            DiffPanel()
                                .environment(diffVM)
                                .environment(changesVM)
                                .frame(height: max(100, geo.size.height - commitAreaHeight - 4))

                            // Draggable divider between diff and commit
                            draggableHDivider { delta in
                                commitAreaHeight = max(80, min(300, commitAreaHeight - delta))
                            }

                            CommitAreaView()
                                .environment(commitVM)
                                .environment(changesVM!)
                                .frame(height: commitAreaHeight)
                        }
                    }
                } else {
                    emptyDiffPanel
                }
            }

            // Log panel — slides up from bottom, resizable
            if logStore.isShowingPanel {
                draggableHDivider { delta in
                    logPanelHeight = max(100, min(600, logPanelHeight - delta))
                }

                LogPanelView()
                    .frame(height: logPanelHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider().background(Theme.borderColor)

            FooterView()
                .environment(changesVM)
        }
        .background(Theme.mainBG)
        .onAppear {
            let service = appVM.gitService
            changesVM = ChangesViewModel(gitService: service)
            diffVM = DiffViewModel(gitService: service)
            commitVM = CommitViewModel(gitService: service)

            // Restore last selected repo and load its files
            appVM.restoreSelectedRepo()
            if let repo = appVM.selectedRepo {
                Task {
                    await appVM.loadRepoInfo()
                    await changesVM?.refresh(repoPath: repo.path)
                }
            }
        }
        .onChange(of: appVM.selectedRepo) { _, newRepo in
            if let repo = newRepo {
                diffVM?.clear()
                changesVM?.selectedFile = nil
                Task {
                    await changesVM?.refresh(repoPath: repo.path)
                }
            } else {
                changesVM?.stagedFiles = []
                changesVM?.unstagedFiles = []
                diffVM?.clear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitFilesChanged)) { _ in
            if let repo = appVM.selectedRepo {
                Task {
                    await changesVM?.refresh(repoPath: repo.path)
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { appVM.errorMessage != nil },
            set: { if !$0 { appVM.errorMessage = nil } }
        )) {
            Button("OK") { appVM.errorMessage = nil }
        } message: {
            Text(appVM.errorMessage ?? "")
        }
    }

    // MARK: - Empty Panels

    private var emptyChangesPanel: some View {
        VStack {
            Spacer()
            Text("Select a repository")
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.mainBG)
    }

    private var emptyDiffPanel: some View {
        VStack {
            Spacer()
            Text("Select a file to view diff")
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.mainBG)
    }

    // MARK: - Draggable Dividers

    /// Vertical divider (drag left/right) — between side-by-side panels
    private func draggableVDivider(onDrag: @escaping (CGFloat) -> Void) -> some View {
        Rectangle()
            .fill(Theme.borderColor)
            .frame(width: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        onDrag(value.translation.width)
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    /// Horizontal divider (drag up/down) — between stacked panels
    private func draggableHDivider(onDrag: @escaping (CGFloat) -> Void) -> some View {
        Rectangle()
            .fill(Theme.borderColor)
            .frame(height: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        onDrag(value.translation.height)
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
