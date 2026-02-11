import SwiftUI

struct HeaderView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        HStack(spacing: 12) {
            // Draggable area for window
            Color.clear
                .frame(width: 76, height: Theme.headerHeight)

            // Branch selector
            if appVM.selectedRepo != nil {
                Menu {
                    let localBranches = appVM.branches.filter { !$0.isRemote }
                    let remoteBranches = appVM.branches.filter { $0.isRemote }

                    ForEach(localBranches) { branch in
                        if branch.isCurrent {
                            Label(branch.name, systemImage: "checkmark")
                        } else {
                            Button(branch.name) {
                                Task { await appVM.checkoutBranch(branch.name) }
                            }
                        }
                    }

                    if !remoteBranches.isEmpty {
                        Divider()
                        Text("Remote").font(.caption)
                        ForEach(remoteBranches) { branch in
                            Button("origin/\(branch.name)") {
                                Task { await appVM.checkoutBranch(branch.name) }
                            }
                        }
                    }

                    Divider()
                    Button {
                        appVM.showManageBranches = true
                    } label: {
                        Label("Manage Branches...", systemImage: "list.bullet")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12))
                        Text(appVM.currentBranch.isEmpty ? "No branch" : appVM.currentBranch)
                            .font(Theme.uiFontMedium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.hoverBG, in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Divider()
                    .frame(height: 16)
                    .background(Theme.borderColor)

                // Push button
                Button {
                    Task { await appVM.push() }
                } label: {
                    Label("Push", systemImage: "arrow.up.circle")
                        .font(Theme.uiFont)
                }
                .buttonStyle(HeaderButtonStyle())

                // Pull button
                Button {
                    Task { await appVM.pull() }
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                        .font(Theme.uiFont)
                }
                .buttonStyle(HeaderButtonStyle())

                // New Branch button
                Button {
                    appVM.showNewBranchSheet = true
                } label: {
                    Label("New Branch", systemImage: "plus")
                        .font(Theme.uiFont)
                }
                .buttonStyle(HeaderButtonStyle())

                // Create PR button
                Button {
                    Task { await appVM.openCreatePR() }
                } label: {
                    Label("Create PR", systemImage: "arrow.up.right.square")
                        .font(Theme.uiFont)
                }
                .buttonStyle(HeaderButtonStyle())

                // Prune button
                HStack(spacing: 2) {
                    Button {
                        Task { await appVM.prune() }
                    } label: {
                        Label("Prune", systemImage: "scissors")
                            .font(Theme.uiFont)
                    }
                    .buttonStyle(HeaderButtonStyle())

                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textDimmed)
                        .help("Prunes stale remote refs and deletes local branches whose remote was deleted")
                }
            }

            Spacer()

            // Theme picker
            ThemePicker()

            Text("EasyGit")
                .font(Theme.uiFontSemibold)
                .foregroundStyle(Theme.textTertiary)
                .padding(.trailing, 12)
        }
        .frame(height: Theme.headerHeight)
        .background(Theme.sidebarBG)
        .sheet(isPresented: .init(
            get: { appVM.showNewBranchSheet },
            set: { appVM.showNewBranchSheet = $0 }
        )) {
            NewBranchSheet()
        }
        .sheet(isPresented: .init(
            get: { appVM.showDeleteBranchConfirmation },
            set: { appVM.showDeleteBranchConfirmation = $0 }
        )) {
            DeleteBranchSheet()
        }
        .sheet(isPresented: .init(
            get: { appVM.showManageBranches },
            set: { appVM.showManageBranches = $0 }
        )) {
            ManageBranchesSheet()
        }
        .alert(
            "Delete Local Branches",
            isPresented: .init(
                get: { appVM.showPruneConfirmation },
                set: { appVM.showPruneConfirmation = $0 }
            )
        ) {
            Button("Cancel", role: .cancel) {
                appVM.cancelPrune()
            }
            Button("Delete", role: .destructive) {
                Task { await appVM.confirmPruneDeletion() }
            }
        } message: {
            let branches = appVM.pruneBranches
            Text("The following local branches will be deleted (they are already deleted on remote):\n\n\(branches.joined(separator: "\n"))")
        }
        // Sensitive data push warning
        .alert("Potential Sensitive Data Detected", isPresented: .init(
            get: { appVM.showPushSecretsWarning },
            set: { if !$0 { appVM.showPushSecretsWarning = false } }
        )) {
            Button("Push Anyway", role: .destructive) {
                Task {
                    appVM.showPushSecretsWarning = false
                    await appVM.performPush()
                }
            }
            Button("Cancel", role: .cancel) {
                appVM.showPushSecretsWarning = false
            }
        } message: {
            let count = appVM.detectedSecrets.count
            let summary = appVM.detectedSecrets.prefix(5).map { "\($0.pattern) in \($0.file)" }.joined(separator: "\n")
            Text("Found \(count) potential secret\(count == 1 ? "" : "s") in unpushed commits:\n\n\(summary)\(count > 5 ? "\n...and \(count - 5) more" : "")")
        }
    }
}

struct ThemePicker: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var tm = themeManager

        HStack(spacing: 4) {
            ForEach(ThemeVariant.allCases, id: \.self) { variant in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tm.variant = variant
                    }
                } label: {
                    Circle()
                        .fill(swatchColor(for: variant))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(tm.variant == variant ? Color.white : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(variant.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.subtleBG, in: Capsule())
    }

    private func swatchColor(for variant: ThemeVariant) -> Color {
        switch variant {
        case .dark: return Color(hex: 0x2D2D2D)
        case .light: return Color(hex: 0xF5F5F5)
        case .lightBlue: return Color(hex: 0xE1EDFA)
        case .glitter: return Color(hex: 0xA855F7)
        }
    }
}

struct HeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                configuration.isPressed
                    ? Theme.pressedBG
                    : Theme.subtleBG,
                in: RoundedRectangle(cornerRadius: 5)
            )
    }
}
