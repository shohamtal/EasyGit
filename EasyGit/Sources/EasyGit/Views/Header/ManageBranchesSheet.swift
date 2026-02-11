import SwiftUI

struct ManageBranchesSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var alsoRemote = false
    @State private var showConfirm = false
    @State private var isDeleting = false

    private var localBranches: [BranchInfo] {
        appVM.branches.filter { !$0.isRemote && !$0.isCurrent }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Branches")
                    .font(Theme.uiFontSemibold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                } else if !selected.isEmpty {
                    Text("\(selected.count) selected")
                        .font(Theme.smallFont)
                        .foregroundStyle(Theme.textDimmed)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().background(Theme.borderColor)

            // Current branch (non-deletable)
            if let current = appVM.branches.first(where: { $0.isCurrent }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text(current.name)
                        .font(Theme.uiFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text("current")
                        .font(Theme.smallFont)
                        .foregroundStyle(Theme.textDimmed)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }

            // Deletable branches
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(localBranches) { branch in
                        HStack(spacing: 8) {
                            // Checkbox
                            Button {
                                toggleSelection(branch.name)
                            } label: {
                                Image(systemName: selected.contains(branch.name) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(selected.contains(branch.name) ? Color.accentColor : Theme.textDimmed)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeleting)

                            Text(branch.name)
                                .font(Theme.uiFont)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            // Quick delete single branch
                            Button {
                                selected = [branch.name]
                                showConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textDimmed)
                            }
                            .buttonStyle(.plain)
                            .help("Delete \(branch.name)")
                            .disabled(isDeleting)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isDeleting else { return }
                            toggleSelection(branch.name)
                        }
                    }
                }
            }
            .frame(minHeight: 100, maxHeight: 300)

            Divider().background(Theme.borderColor)

            // Footer
            VStack(spacing: 12) {
                Toggle("Also delete on remote", isOn: $alsoRemote)
                    .font(Theme.uiFont)
                    .foregroundStyle(Theme.textSecondary)
                    .toggleStyle(.checkbox)
                    .disabled(isDeleting)

                HStack {
                    Button("Select All") {
                        selected = Set(localBranches.map(\.name))
                    }
                    .disabled(localBranches.isEmpty || isDeleting)

                    Button("Select None") {
                        selected.removeAll()
                    }
                    .disabled(selected.isEmpty || isDeleting)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isDeleting)

                    Button("Delete Selected") {
                        showConfirm = true
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty || isDeleting)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 380)
        .background(Theme.sidebarBG)
        .alert(
            "Delete \(selected.count) Branch\(selected.count == 1 ? "" : "es")?",
            isPresented: $showConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteBranches()
            }
        } message: {
            let names = selected.sorted().joined(separator: ", ")
            Text("\(names)\(alsoRemote ? "\n\nAlso from remote." : "")")
        }
    }

    private func toggleSelection(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func deleteBranches() {
        let toDelete = Array(selected)
        let deleteRemote = alsoRemote
        isDeleting = true
        Task {
            guard let repo = appVM.selectedRepo else { return }
            let logRef = appVM.logStore
            do {
                try await appVM.gitService.deleteLocalBranches(at: repo.path, branches: toDelete) { text, isErr in
                    logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
                }
                if deleteRemote {
                    for branch in toDelete {
                        do {
                            try await appVM.gitService.deleteRemoteBranch(at: repo.path, branch: branch) { text, isErr in
                                logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
                            }
                        } catch {
                            await MainActor.run {
                                logRef.append("Remote not found for \(branch): \(error.localizedDescription)", kind: .stderr)
                            }
                        }
                    }
                }
                await appVM.loadRepoInfo()
                await MainActor.run {
                    logRef.append("Deleted \(toDelete.count) branch\(toDelete.count == 1 ? "" : "es")", kind: .info)
                    selected.removeAll()
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    logRef.append("Delete failed: \(error.localizedDescription)", kind: .stderr)
                    selected.removeAll()
                    isDeleting = false
                }
            }
        }
    }
}
