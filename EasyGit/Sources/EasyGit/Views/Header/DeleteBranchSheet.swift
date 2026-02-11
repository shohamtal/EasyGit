import SwiftUI

struct DeleteBranchSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false

    var body: some View {
        @Bindable var vm = appVM

        VStack(spacing: 16) {
            Text("Delete Branch")
                .font(Theme.uiFontSemibold)
                .foregroundStyle(Theme.textPrimary)

            Text("Delete branch \"\(appVM.branchToDelete)\" locally?")
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Toggle("Also delete on remote", isOn: $vm.deleteBranchAlsoRemote)
                .font(Theme.uiFont)
                .foregroundStyle(Theme.textSecondary)
                .toggleStyle(.checkbox)
                .disabled(isDeleting)

            HStack {
                Button("Cancel") {
                    appVM.cancelDeleteBranch()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isDeleting)

                Spacer()

                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Delete") {
                    isDeleting = true
                    Task {
                        await appVM.confirmDeleteBranch()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .foregroundStyle(.red)
                .disabled(isDeleting)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Theme.sidebarBG)
    }
}
