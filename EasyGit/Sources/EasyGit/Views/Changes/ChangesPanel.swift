import SwiftUI

struct ChangesPanel: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(ChangesViewModel.self) private var changesVM
    @Environment(DiffViewModel.self) private var diffVM
    @Binding var unstagedRatio: CGFloat
    @State private var showRevertConfirmation = false

    var body: some View {
        GeometryReader { geo in
            let dividerHeight: CGFloat = 4
            let available = geo.size.height - dividerHeight
            let topHeight = max(60, available * unstagedRatio)
            let bottomHeight = max(60, available - topHeight)

            VStack(spacing: 0) {
                // Unstaged changes (top)
                VStack(spacing: 0) {
                    sectionHeader(
                        title: "Unstaged Changes",
                        count: changesVM.unstagedFiles.count,
                        action: { Task { await stageAll() } },
                        actionIcon: "plus.circle",
                        actionTooltip: "Stage All"
                    )

                    Divider().background(Theme.borderColor)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(changesVM.unstagedFiles) { file in
                                UnstagedFileRow(file: file) {
                                    selectFile(file, staged: false)
                                } onToggle: {
                                    Task { await stage(file) }
                                }
                                .contextMenu {
                                    if changesVM.selectedUnstagedPaths.contains(file.path) && changesVM.selectedUnstagedPaths.count > 1 {
                                        Button("Revert \(changesVM.selectedUnstagedPaths.count) Files...") {
                                            showRevertConfirmation = true
                                        }
                                        Button("Stage \(changesVM.selectedUnstagedPaths.count) Files") {
                                            Task { await stageSelected() }
                                        }
                                    } else {
                                        Button("Revert \"\(file.path)\"...") {
                                            changesVM.selectedUnstagedPaths = [file.path]
                                            showRevertConfirmation = true
                                        }
                                        Button("Stage \"\(file.path)\"") {
                                            Task { await stage(file) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: topHeight)

                // Draggable divider between unstaged and staged
                Rectangle()
                    .fill(Theme.borderColor)
                    .frame(height: dividerHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let newRatio = unstagedRatio + value.translation.height / available
                                unstagedRatio = max(0.15, min(0.85, newRatio))
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeUpDown.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                // Staged changes (bottom)
                VStack(spacing: 0) {
                    sectionHeader(
                        title: "Staged Changes",
                        count: changesVM.stagedFiles.count,
                        action: { Task { await unstageAll() } },
                        actionIcon: "minus.circle",
                        actionTooltip: "Unstage All"
                    )

                    Divider().background(Theme.borderColor)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(changesVM.stagedFiles) { file in
                                FileChangeRow(
                                    file: file,
                                    isStaged: true,
                                    isSelected: changesVM.selectedFile?.path == file.path && changesVM.selectedFileIsStaged
                                ) {
                                    selectFile(file, staged: true)
                                } onToggle: {
                                    Task { await unstage(file) }
                                }
                            }
                        }
                    }
                }
                .frame(height: bottomHeight)
            }
        }
        .background(Theme.mainBG)
        .keyboardShortcut(for: .revert) {
            if !changesVM.selectedUnstagedPaths.isEmpty {
                showRevertConfirmation = true
            }
        }
        .alert(
            "Revert Changes",
            isPresented: $showRevertConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Revert", role: .destructive) {
                Task { await revertSelected() }
            }
        } message: {
            let count = changesVM.selectedUnstagedPaths.count
            if count == 1, let path = changesVM.selectedUnstagedPaths.first {
                let name = (path as NSString).lastPathComponent
                Text("Are you sure you want to revert \"\(name)\"? This will discard all unstaged changes and cannot be undone.")
            } else {
                Text("Are you sure you want to revert \(count) files? This will discard all unstaged changes and cannot be undone.")
            }
        }
    }

    private func sectionHeader(title: String, count: Int, action: @escaping () -> Void, actionIcon: String, actionTooltip: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.uiFontMedium)
                .foregroundStyle(Theme.textSecondary)

            Text("\(count)")
                .font(Theme.smallFont)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.badgeBG, in: Capsule())

            Spacer()

            Button(action: action) {
                Image(systemName: actionIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(actionTooltip)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.panelHeaderBG)
    }

    private func selectFile(_ file: GitFileChange, staged: Bool) {
        changesVM.selectFile(file, staged: staged)
        if let repo = appVM.selectedRepo {
            Task {
                await diffVM.loadDiff(repoPath: repo.path, file: file, staged: staged)
            }
        }
    }

    private func stage(_ file: GitFileChange) async {
        guard let repo = appVM.selectedRepo else { return }
        let neighbor = neighborFile(of: file, in: changesVM.unstagedFiles)
        await changesVM.stageFile(file, repoPath: repo.path)
        selectNeighborIfAvailable(neighbor, staged: false, repoPath: repo.path)
    }

    private func stageSelected() async {
        guard let repo = appVM.selectedRepo else { return }
        for file in changesVM.selectedUnstagedFiles {
            await changesVM.stageFile(file, repoPath: repo.path)
        }
    }

    private func unstage(_ file: GitFileChange) async {
        guard let repo = appVM.selectedRepo else { return }
        let neighbor = neighborFile(of: file, in: changesVM.stagedFiles)
        await changesVM.unstageFile(file, repoPath: repo.path)
        selectNeighborIfAvailable(neighbor, staged: true, repoPath: repo.path)
    }

    private func stageAll() async {
        guard let repo = appVM.selectedRepo else { return }
        await changesVM.stageAll(repoPath: repo.path)
    }

    private func unstageAll() async {
        guard let repo = appVM.selectedRepo else { return }
        await changesVM.unstageAll(repoPath: repo.path)
    }

    private func revertSelected() async {
        guard let repo = appVM.selectedRepo else { return }
        let paths = Array(changesVM.selectedUnstagedPaths)
        await changesVM.revertFiles(paths: paths, repoPath: repo.path)
    }

    /// Returns the next file in the list, or the previous one if the file is last.
    private func neighborFile(of file: GitFileChange, in list: [GitFileChange]) -> GitFileChange? {
        guard let idx = list.firstIndex(where: { $0.path == file.path }) else { return nil }
        if idx + 1 < list.count {
            return list[idx + 1]
        } else if idx > 0 {
            return list[idx - 1]
        }
        return nil
    }

    /// After staging/unstaging, select the neighbor file if it still exists in the refreshed list.
    private func selectNeighborIfAvailable(_ neighbor: GitFileChange?, staged: Bool, repoPath: String) {
        guard let neighbor else { return }
        let list = staged ? changesVM.stagedFiles : changesVM.unstagedFiles
        guard let match = list.first(where: { $0.path == neighbor.path }) else { return }
        if !staged {
            changesVM.selectedUnstagedPaths = [match.path]
        }
        selectFile(match, staged: staged)
    }
}

// MARK: - Unstaged file row with multi-select support

struct UnstagedFileRow: View {
    @Environment(ChangesViewModel.self) private var changesVM
    let file: GitFileChange
    let onSelect: () -> Void
    let onToggle: () -> Void

    private var isMultiSelected: Bool {
        changesVM.isUnstagedSelected(file)
    }

    private var isDiffSelected: Bool {
        changesVM.selectedFile?.path == file.path && !changesVM.selectedFileIsStaged
    }

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox to stage
            Button(action: onToggle) {
                Image(systemName: "square")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)

            // Status badge
            Text(file.status.label)
                .font(Theme.smallFontMedium)
                .foregroundStyle(Theme.badgeColor(for: file.status))
                .frame(width: 16, height: 16)
                .background(Theme.badgeColor(for: file.status).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))

            // Full relative path
            Text(file.path)
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            let extending = NSEvent.modifierFlags.contains(.command)
            changesVM.toggleUnstagedSelection(file, extending: extending)
            onSelect()
        }
    }

    private var rowBackground: Color {
        if isMultiSelected {
            return Theme.primary.opacity(0.2)
        } else if isDiffSelected {
            return Theme.primary.opacity(0.1)
        }
        return .clear
    }
}

// MARK: - Keyboard shortcut helper

struct KeyboardShortcutAction: ViewModifier {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background {
                Button("") { action() }
                    .keyboardShortcut(key, modifiers: modifiers)
                    .hidden()
            }
    }
}

enum AppShortcut {
    case revert
}

extension View {
    func keyboardShortcut(for shortcut: AppShortcut, action: @escaping () -> Void) -> some View {
        switch shortcut {
        case .revert:
            return AnyView(self.modifier(KeyboardShortcutAction(key: "j", modifiers: .command, action: action)))
        }
    }
}
