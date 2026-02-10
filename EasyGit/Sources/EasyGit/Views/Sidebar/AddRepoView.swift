import SwiftUI
import UniformTypeIdentifiers

struct AddRepoView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var scanResults: [Repository] = []
    @State private var showScanResults = false
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Repository")
                .font(Theme.uiFontSemibold)
                .foregroundStyle(Theme.textPrimary)

            // Group name
            HStack {
                Text("Group (optional):")
                    .font(Theme.uiFont)
                    .foregroundStyle(Theme.textSecondary)
                TextField("Group name", text: $groupName)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            if showScanResults {
                scanResultsView
            } else if isScanning {
                ProgressView("Scanning...")
                    .controlSize(.small)
            } else {
                // Add single repo
                Button {
                    pickFolder { url in
                        let name = url.lastPathComponent
                        let gID = resolveGroupID()
                        let repo = Repository(name: name, path: url.path, groupID: gID)
                        appVM.addRepository(repo)
                        dismiss()
                    }
                } label: {
                    Label("Add Repository Folder", systemImage: "folder.badge.plus")
                        .font(Theme.uiFont)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonStyle(.bordered)

                // Scan directory
                Button {
                    pickFolder { url in
                        isScanning = true
                        Task {
                            let gName = groupName.isEmpty ? nil : groupName
                            let found = await appVM.scanDirectory(at: url, groupName: gName)
                            await MainActor.run {
                                scanResults = found
                                showScanResults = true
                                isScanning = false
                            }
                        }
                    }
                } label: {
                    Label("Scan Directory for Repos", systemImage: "magnifyingglass")
                        .font(Theme.uiFont)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 200)
        .background(Theme.sidebarBG)
    }

    private var scanResultsView: some View {
        VStack(spacing: 8) {
            Text("Found \(scanResults.count) repositories")
                .font(Theme.uiFontMedium)
                .foregroundStyle(Theme.textPrimary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(scanResults) { repo in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(Theme.primary)
                            Text(repo.name)
                                .font(Theme.uiFont)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 200)

            Button("Add All") {
                for repo in scanResults {
                    appVM.addRepository(repo)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(scanResults.isEmpty)
        }
    }

    private func pickFolder(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(url)
            }
        }
    }

    private func resolveGroupID() -> UUID? {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        if let existing = appVM.groups.first(where: { $0.name == name }) {
            return existing.id
        }
        let group = RepositoryGroup(name: name)
        appVM.addGroup(group)
        return group.id
    }
}
