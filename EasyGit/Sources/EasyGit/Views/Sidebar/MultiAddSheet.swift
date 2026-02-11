import SwiftUI

struct MultiAddSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .choose
    @State private var groupName = ""

    private enum Step {
        case choose
        case nameGroup
    }

    var body: some View {
        VStack(spacing: 16) {
            switch step {
            case .choose:
                chooseView
            case .nameGroup:
                nameGroupView
            }
        }
        .padding(20)
        .frame(minWidth: 400)
        .background(Theme.sidebarBG)
    }

    private var chooseView: some View {
        VStack(spacing: 16) {
            Text("Add Multiple Repos")
                .font(Theme.uiFontSemibold)
                .foregroundStyle(Theme.textPrimary)

            Text("You selected \(appVM.multiAddURLs.count) folders:")
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(appVM.multiAddURLs, id: \.absoluteString) { url in
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                        Text(url.lastPathComponent)
                            .font(Theme.uiFont)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.subtleBG, in: RoundedRectangle(cornerRadius: 6))

            Text("Group these repos or add each one individually?")
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textSecondary)

            HStack {
                Button("Cancel") {
                    appVM.multiAddURLs = []
                    appVM.showMultiAddConfirmation = false
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Individually") {
                    Task {
                        await appVM.confirmMultiAddIndividually()
                        dismiss()
                    }
                }

                Button("Group...") {
                    groupName = ""
                    step = .nameGroup
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var nameGroupView: some View {
        VStack(spacing: 16) {
            Text("Create Group")
                .font(Theme.uiFontSemibold)
                .foregroundStyle(Theme.textPrimary)

            TextField("Group name", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createGroup() }

            HStack {
                Button("Back") {
                    step = .choose
                }

                Spacer()

                Button("Create Group") {
                    createGroup()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func createGroup() {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            await appVM.confirmMultiAddAsGroup(name: name)
            dismiss()
        }
    }
}
