import Foundation

@Observable
final class ChangesViewModel {
    var stagedFiles: [GitFileChange] = []
    var unstagedFiles: [GitFileChange] = []
    var selectedFile: GitFileChange?
    var selectedFileIsStaged: Bool = false
    var isLoading: Bool = false
    var unstagedRatio: CGFloat = 0.5

    // Multi-selection for unstaged files
    var selectedUnstagedPaths: Set<String> = []

    private let gitService: GitService

    init(gitService: GitService) {
        self.gitService = gitService
    }

    func refresh(repoPath: String) async {
        await MainActor.run { self.isLoading = true }
        do {
            let result = try await gitService.status(at: repoPath)
            await MainActor.run {
                self.stagedFiles = result.staged
                self.unstagedFiles = result.unstaged
                self.isLoading = false

                // Clear selection if file no longer present
                if let selected = self.selectedFile {
                    let allFiles = result.staged + result.unstaged
                    if !allFiles.contains(where: { $0.path == selected.path }) {
                        self.selectedFile = nil
                    }
                }

                // Prune multi-selection
                let currentPaths = Set(result.unstaged.map(\.path))
                self.selectedUnstagedPaths = self.selectedUnstagedPaths.intersection(currentPaths)
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }

    func stageFile(_ file: GitFileChange, repoPath: String) async {
        do {
            try await gitService.stageFile(at: repoPath, file: file.path)
            await refresh(repoPath: repoPath)
        } catch { }
    }

    func unstageFile(_ file: GitFileChange, repoPath: String) async {
        do {
            try await gitService.unstageFile(at: repoPath, file: file.path)
            await refresh(repoPath: repoPath)
        } catch { }
    }

    func stageAll(repoPath: String) async {
        do {
            try await gitService.stageAll(at: repoPath)
            await refresh(repoPath: repoPath)
        } catch { }
    }

    func unstageAll(repoPath: String) async {
        do {
            try await gitService.unstageAll(at: repoPath)
            await refresh(repoPath: repoPath)
        } catch { }
    }

    func selectFile(_ file: GitFileChange, staged: Bool) {
        selectedFile = file
        selectedFileIsStaged = staged
    }

    // MARK: - Multi-select

    func toggleUnstagedSelection(_ file: GitFileChange, extending: Bool) {
        if extending {
            if selectedUnstagedPaths.contains(file.path) {
                selectedUnstagedPaths.remove(file.path)
            } else {
                selectedUnstagedPaths.insert(file.path)
            }
        } else {
            selectedUnstagedPaths = [file.path]
        }
    }

    func isUnstagedSelected(_ file: GitFileChange) -> Bool {
        selectedUnstagedPaths.contains(file.path)
    }

    var selectedUnstagedFiles: [GitFileChange] {
        unstagedFiles.filter { selectedUnstagedPaths.contains($0.path) }
    }

    // MARK: - Revert

    func revertFiles(paths: [String], repoPath: String) async {
        do {
            try await gitService.revertFiles(at: repoPath, files: paths)
            await MainActor.run {
                self.selectedUnstagedPaths = []
                self.selectedFile = nil
            }
            await refresh(repoPath: repoPath)
        } catch { }
    }
}
