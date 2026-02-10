import Foundation

@Observable
final class CommitViewModel {
    var commitMessage: String = ""
    var isCommitting: Bool = false
    var statusMessage: String?

    private let gitService: GitService

    init(gitService: GitService) {
        self.gitService = gitService
    }

    func commit(repoPath: String) async -> Bool {
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.statusMessage = "Commit message cannot be empty"
            }
            return false
        }

        await MainActor.run {
            self.isCommitting = true
            self.statusMessage = nil
        }

        do {
            try await gitService.commit(at: repoPath, message: commitMessage)
            await MainActor.run {
                self.commitMessage = ""
                self.isCommitting = false
                self.statusMessage = "Committed successfully"
            }
            return true
        } catch {
            await MainActor.run {
                self.isCommitting = false
                self.statusMessage = error.localizedDescription
            }
            return false
        }
    }
}
