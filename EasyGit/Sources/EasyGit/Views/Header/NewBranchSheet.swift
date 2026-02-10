import SwiftUI

struct NewBranchSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var branchName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Branch")
                .font(Theme.uiFontSemibold)
                .foregroundStyle(Theme.textPrimary)

            TextField("Branch name", text: $branchName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createBranch() }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createBranch()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(Theme.sidebarBG)
    }

    private func createBranch() {
        let name = branchName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            await appVM.createBranch(name: name)
            dismiss()
        }
    }
}
