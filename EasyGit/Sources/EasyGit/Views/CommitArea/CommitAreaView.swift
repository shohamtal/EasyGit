import SwiftUI

struct CommitAreaView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(CommitViewModel.self) private var commitVM
    @Environment(ChangesViewModel.self) private var changesVM

    var body: some View {
        @Bindable var vm = commitVM

        VStack(spacing: 8) {
            // Commit message
            TextEditor(text: $vm.commitMessage)
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.inputStroke, lineWidth: 1)
                )
                .frame(minHeight: 60, maxHeight: 80)

            // Status message
            if let status = commitVM.statusMessage {
                Text(status)
                    .font(Theme.smallFont)
                    .foregroundStyle(Theme.textTertiary)
            }

            // Buttons
            HStack(spacing: 8) {
                Button("Rescan") {
                    rescan()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Spacer()

                Button {
                    Task { await commitWithProtectedCheck() }
                } label: {
                    Text("Commit to \(appVM.currentBranch.isEmpty ? "branch" : appVM.currentBranch)")
                        .font(Theme.uiFontMedium)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(commitVM.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || changesVM.stagedFiles.isEmpty)
            }
        }
        .padding(12)
        .background(Theme.mainBG)
        // Protected branch commit confirmation
        .alert("Protected Branch", isPresented: .init(
            get: { appVM.showProtectedBranchWarning },
            set: { if !$0 { appVM.showProtectedBranchWarning = false } }
        )) {
            Button("Commit Anyway", role: .destructive) {
                Task { await forceCommit() }
            }
            Button("Cancel", role: .cancel) {
                appVM.showProtectedBranchWarning = false
            }
        } message: {
            Text("You are committing directly to \"\(appVM.protectedBranchName)\", which is a protected branch. Are you sure?")
        }
    }

    private func rescan() {
        guard let repo = appVM.selectedRepo else { return }
        Task {
            await changesVM.refresh(repoPath: repo.path)
        }
    }

    private func commitWithProtectedCheck() async {
        guard let repo = appVM.selectedRepo else { return }
        let branch = appVM.currentBranch

        // Check if branch is protected
        let isProtected = await appVM.gitService.isProtectedBranch(at: repo.path, branch: branch)
        if isProtected {
            await MainActor.run {
                appVM.protectedBranchName = branch
                appVM.pendingCommitMessage = commitVM.commitMessage
                appVM.pendingCommitRepoPath = repo.path
                appVM.showProtectedBranchWarning = true
            }
            return
        }

        await commit()
    }

    private func commit() async {
        guard let repo = appVM.selectedRepo else { return }
        let success = await commitVM.commit(repoPath: repo.path)
        if success {
            await changesVM.refresh(repoPath: repo.path)
        }
    }

    private func forceCommit() async {
        let success = await commitVM.commit(repoPath: appVM.pendingCommitRepoPath)
        if success {
            if let repo = appVM.selectedRepo {
                await changesVM.refresh(repoPath: repo.path)
            }
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.uiFont)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                configuration.isPressed ? Theme.pressedBG : Theme.subtleBG,
                in: RoundedRectangle(cornerRadius: 5)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.uiFontMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                (isEnabled ? Theme.primary : Theme.primary.opacity(0.4))
                    .opacity(configuration.isPressed ? 0.85 : 1.0),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .shadow(color: Theme.primary.opacity(isEnabled ? 0.2 : 0), radius: 8)
    }
}
