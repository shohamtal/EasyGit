import Foundation
import SwiftUI

@Observable
final class AppViewModel {
    var repositories: [Repository] = []
    var groups: [RepositoryGroup] = []
    var selectedRepo: Repository?
    var currentBranch: String = ""
    var branches: [BranchInfo] = []
    var statusMessage: String = "Ready"
    var isLoading: Bool = false
    var showAddRepoSheet = false
    var showNewBranchSheet = false
    var errorMessage: String?

    // Protected branch / secrets warnings
    var showProtectedBranchWarning = false
    var protectedBranchName = ""
    var pendingCommitMessage = ""
    var pendingCommitRepoPath = ""

    var showPushSecretsWarning = false
    var detectedSecrets: [GitService.SensitiveMatch] = []

    // Branches management
    var showManageBranches = false

    // Delete branch
    var showDeleteBranchConfirmation = false
    var branchToDelete: String = ""
    var deleteBranchAlsoRemote = false

    // Multi-add repos
    var showMultiAddConfirmation = false
    var multiAddURLs: [URL] = []

    let gitService = GitService()
    let logStore = LogStore()
    private var fileWatcher: FileWatcher?

    init() {
        repositories = Storage.loadRepositories()
        groups = Storage.loadGroups()
    }

    // MARK: - Repo Management

    func addRepository(_ repo: Repository) {
        // Avoid duplicates by path
        guard !repositories.contains(where: { $0.path == repo.path }) else { return }
        repositories.append(repo)
        Storage.saveRepositories(repositories)
    }

    func removeRepository(_ repo: Repository) {
        repositories.removeAll { $0.id == repo.id }
        if selectedRepo?.id == repo.id {
            selectedRepo = nil
        }
        Storage.saveRepositories(repositories)
    }

    func addGroup(_ group: RepositoryGroup) {
        // Avoid duplicate groups by path or workspace
        if let path = group.path, groups.contains(where: { $0.path == path }) { return }
        if let ws = group.workspacePath, groups.contains(where: { $0.workspacePath == ws }) { return }
        groups.append(group)
        Storage.saveGroups(groups)
    }

    func renameGroup(_ group: RepositoryGroup, to newName: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = newName
        Storage.saveGroups(groups)
    }

    func removeGroup(_ group: RepositoryGroup) {
        // Remove all repos in this group
        repositories.removeAll { $0.groupID == group.id }
        if let sel = selectedRepo, sel.groupID == group.id {
            selectedRepo = nil
        }
        groups.removeAll { $0.id == group.id }
        Storage.saveGroups(groups)
        Storage.saveRepositories(repositories)
    }

    // MARK: - Smart Add (single repo, auto-detect group, or workspace)

    func smartAdd(url: URL) async {
        // Handle .code-workspace files
        if url.pathExtension == "code-workspace" {
            await addFromWorkspace(url: url)
            return
        }

        let path = url.path
        let isRepo = await gitService.isGitRepository(at: path)

        if isRepo {
            // It's a git repo — add directly as ungrouped
            let repo = Repository(name: url.lastPathComponent, path: path)
            await MainActor.run {
                self.addRepository(repo)
                self.selectRepo(repo)
            }
            return
        }

        // Not a git repo — check immediate children for git repos
        let childRepos = await scanImmediateChildren(at: url)

        if childRepos.isEmpty {
            await MainActor.run {
                self.errorMessage = "No git repositories found in \"\(url.lastPathComponent)\" or its immediate subdirectories."
            }
            return
        }

        // Create a group from the parent dir
        let group = RepositoryGroup(name: url.lastPathComponent, path: path)
        await MainActor.run {
            self.addGroup(group)
            let groupID = self.groups.first(where: { $0.path == path })?.id ?? group.id
            for var repo in childRepos {
                repo.groupID = groupID
                self.addRepository(repo)
            }
        }
    }

    // MARK: - Workspace File Support

    func addFromWorkspace(url: URL) async {
        let workspacePath = url.path
        let baseDir = url.deletingLastPathComponent()

        guard let folders = parseWorkspaceFolders(at: url) else {
            await MainActor.run {
                self.errorMessage = "Could not parse workspace file."
            }
            return
        }

        // Resolve folder paths relative to workspace file location
        var childRepos: [Repository] = []
        for folderPath in folders {
            let resolved: URL
            if folderPath.hasPrefix("/") {
                resolved = URL(fileURLWithPath: folderPath)
            } else {
                resolved = baseDir.appendingPathComponent(folderPath).standardized
            }

            if await gitService.isGitRepository(at: resolved.path) {
                let repo = Repository(name: resolved.lastPathComponent, path: resolved.path)
                childRepos.append(repo)
            }
        }

        if childRepos.isEmpty {
            await MainActor.run {
                self.errorMessage = "No git repositories found in workspace folders."
            }
            return
        }

        // Group name from workspace filename (strip .code-workspace extension)
        let wsName = url.deletingPathExtension().lastPathComponent
        let group = RepositoryGroup(name: wsName, workspacePath: workspacePath)

        let resolvedRepos = childRepos
        await MainActor.run {
            self.addGroup(group)
            let groupID = self.groups.first(where: { $0.workspacePath == workspacePath })?.id ?? group.id
            for var repo in resolvedRepos {
                repo.groupID = groupID
                self.addRepository(repo)
            }
        }
    }

    private func parseWorkspaceFolders(at url: URL) -> [String]? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        // VS Code workspace files allow JS-style comments — strip them before parsing
        let stripped = stripJSONComments(raw)

        guard let data = stripped.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let folders = json["folders"] as? [[String: Any]] else {
            return nil
        }
        return folders.compactMap { $0["path"] as? String }
    }

    private func stripJSONComments(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        var inString = false
        var escaped = false

        while i < input.endIndex {
            let c = input[i]

            if escaped {
                result.append(c)
                escaped = false
                i = input.index(after: i)
                continue
            }

            if c == "\\" && inString {
                result.append(c)
                escaped = true
                i = input.index(after: i)
                continue
            }

            if c == "\"" {
                inString.toggle()
                result.append(c)
                i = input.index(after: i)
                continue
            }

            if !inString {
                let next = input.index(after: i)
                if c == "/" && next < input.endIndex {
                    if input[next] == "/" {
                        // Line comment — skip to end of line
                        if let eol = input[i...].firstIndex(of: "\n") {
                            i = eol
                        } else {
                            break
                        }
                        continue
                    } else if input[next] == "*" {
                        // Block comment — skip to */
                        let afterStar = input.index(next, offsetBy: 1)
                        if let end = input.range(of: "*/", range: afterStar..<input.endIndex) {
                            i = end.upperBound
                        } else {
                            break
                        }
                        continue
                    }
                }
            }

            result.append(c)
            i = input.index(after: i)
        }

        return result
    }

    func rescanWorkspaceGroup(_ group: RepositoryGroup) async {
        guard let wsPath = group.workspacePath else { return }
        let wsURL = URL(fileURLWithPath: wsPath)
        let baseDir = wsURL.deletingLastPathComponent()

        guard let folders = parseWorkspaceFolders(at: wsURL) else { return }

        var scannedRepos: [Repository] = []
        for folderPath in folders {
            let resolved: URL
            if folderPath.hasPrefix("/") {
                resolved = URL(fileURLWithPath: folderPath)
            } else {
                resolved = baseDir.appendingPathComponent(folderPath).standardized
            }
            if await gitService.isGitRepository(at: resolved.path) {
                scannedRepos.append(Repository(name: resolved.lastPathComponent, path: resolved.path))
            }
        }

        let resolvedScanned = scannedRepos
        await MainActor.run {
            let currentPaths = Set(self.repos(in: group).map(\.path))
            let scannedPaths = Set(resolvedScanned.map(\.path))

            // Remove repos no longer in workspace
            let removedPaths = currentPaths.subtracting(scannedPaths)
            for path in removedPaths {
                self.repositories.removeAll { $0.path == path && $0.groupID == group.id }
                if self.selectedRepo?.path == path { self.selectedRepo = nil }
            }

            // Add new repos from workspace
            for var repo in resolvedScanned where !currentPaths.contains(repo.path) {
                repo.groupID = group.id
                self.repositories.append(repo)
            }

            Storage.saveRepositories(self.repositories)
            self.statusMessage = "Rescanned \(group.name)"
        }
    }

    // MARK: - Rescan Group

    func rescanGroup(_ group: RepositoryGroup) async {
        // Workspace-based groups use their own rescan logic
        if group.workspacePath != nil {
            await rescanWorkspaceGroup(group)
            return
        }

        guard let groupPath = group.path else { return }
        let url = URL(fileURLWithPath: groupPath)
        let childRepos = await scanImmediateChildren(at: url)

        await MainActor.run {
            let currentPaths = Set(self.repos(in: group).map(\.path))
            let scannedPaths = Set(childRepos.map(\.path))

            // Remove repos that no longer exist
            let removedPaths = currentPaths.subtracting(scannedPaths)
            for path in removedPaths {
                self.repositories.removeAll { $0.path == path && $0.groupID == group.id }
                if self.selectedRepo?.path == path {
                    self.selectedRepo = nil
                }
            }

            // Add new repos
            for var repo in childRepos where !currentPaths.contains(repo.path) {
                repo.groupID = group.id
                self.repositories.append(repo)
            }

            Storage.saveRepositories(self.repositories)
            self.statusMessage = "Rescanned \(group.name)"
        }
    }

    // MARK: - Scan immediate children (one level deep)

    private func scanImmediateChildren(at url: URL) async -> [Repository] {
        let fm = FileManager.default
        var found: [Repository] = []

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for childURL in contents {
            guard let resourceValues = try? childURL.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else { continue }

            if await gitService.isGitRepository(at: childURL.path) {
                let repo = Repository(name: childURL.lastPathComponent, path: childURL.path)
                found.append(repo)
            }
        }

        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Scan Directory (deep, legacy)

    func scanDirectory(at url: URL, groupName: String?) async -> [Repository] {
        var found: [Repository] = []
        let fm = FileManager.default

        let groupID: UUID?
        if let name = groupName, !name.isEmpty {
            let group = RepositoryGroup(name: name, path: url.path)
            await MainActor.run {
                self.addGroup(group)
            }
            groupID = group.id
        } else {
            groupID = nil
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == ".git" {
                let repoPath = fileURL.deletingLastPathComponent().path
                let name = fileURL.deletingLastPathComponent().lastPathComponent
                if await gitService.isGitRepository(at: repoPath) {
                    let repo = Repository(name: name, path: repoPath, groupID: groupID)
                    found.append(repo)
                }
                enumerator.skipDescendants()
            }
        }

        return found
    }

    // MARK: - Selection

    func selectRepo(_ repo: Repository) {
        selectedRepo = repo
        Storage.saveSelectedRepoPath(repo.path)
        Task {
            await loadRepoInfo()
        }
        setupFileWatcher(for: repo)
    }

    func restoreSelectedRepo() {
        guard selectedRepo == nil,
              let path = Storage.loadSelectedRepoPath(),
              let repo = repositories.first(where: { $0.path == path }) else { return }
        selectedRepo = repo
        setupFileWatcher(for: repo)
    }

    func loadRepoInfo() async {
        guard let repo = selectedRepo else { return }

        do {
            let branch = try await gitService.currentBranch(at: repo.path)
            let branchList = try await gitService.branches(at: repo.path)
            await MainActor.run {
                self.currentBranch = branch
                self.branches = branchList
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Branch Operations

    func checkoutBranch(_ branch: String) async {
        guard let repo = selectedRepo else { return }
        do {
            try await gitService.checkout(at: repo.path, branch: branch)
            await loadRepoInfo()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func createBranch(name: String) async {
        guard let repo = selectedRepo else { return }
        do {
            try await gitService.createBranch(at: repo.path, name: name)
            await loadRepoInfo()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Delete Branch

    func requestDeleteBranch(_ branchName: String) {
        branchToDelete = branchName
        deleteBranchAlsoRemote = false
        showDeleteBranchConfirmation = true
    }

    func confirmDeleteBranch() async {
        guard let repo = selectedRepo, !branchToDelete.isEmpty else { return }
        let logRef = logStore
        let branch = branchToDelete
        let alsoRemote = deleteBranchAlsoRemote

        await MainActor.run {
            self.showDeleteBranchConfirmation = false
            self.isLoading = true
            self.statusMessage = "Deleting branch..."
        }

        do {
            try await gitService.deleteLocalBranches(at: repo.path, branches: [branch]) { text, isErr in
                logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
            }
            var remoteNote = ""
            if alsoRemote {
                do {
                    try await gitService.deleteRemoteBranch(at: repo.path, branch: branch) { text, isErr in
                        logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
                    }
                    remoteNote = " (local + remote)"
                } catch {
                    remoteNote = " (local only — not found on remote)"
                    await MainActor.run {
                        logRef.append("Remote branch not found: \(error.localizedDescription)", kind: .stderr)
                    }
                }
            }
            await loadRepoInfo()
            let finalNote = remoteNote
            await MainActor.run {
                logRef.append("Deleted branch \(branch)\(finalNote)", kind: .info)
                self.statusMessage = "Branch deleted"
                self.isLoading = false
                self.branchToDelete = ""
            }
        } catch {
            await MainActor.run {
                logRef.append("Delete branch failed: \(error.localizedDescription)", kind: .stderr)
                self.statusMessage = "Delete branch failed"
                self.isLoading = false
                self.branchToDelete = ""
            }
        }
    }

    func cancelDeleteBranch() {
        showDeleteBranchConfirmation = false
        branchToDelete = ""
    }

    // MARK: - Push / Pull

    func push() async {
        guard let repo = selectedRepo else { return }

        // Scan for sensitive data before pushing
        let secrets = await gitService.scanUnpushedForSecrets(at: repo.path)
        if !secrets.isEmpty {
            await MainActor.run {
                self.detectedSecrets = secrets
                self.showPushSecretsWarning = true
            }
            return
        }

        await performPush()
    }

    func performPush() async {
        guard let repo = selectedRepo else { return }
        let logRef = logStore
        await MainActor.run {
            self.isLoading = true
            self.statusMessage = "Pushing..."
            logRef.append("$ git push", kind: .command)
        }
        do {
            try await gitService.pushLogged(at: repo.path, branch: currentBranch) { text, isErr in
                logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
            }
            await MainActor.run {
                logRef.append("Push complete", kind: .info)
                self.statusMessage = "Push complete"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                logRef.append("Push failed: \(error.localizedDescription)", kind: .stderr)
                self.statusMessage = "Push failed"
                self.isLoading = false
            }
        }
    }

    func pull() async {
        guard let repo = selectedRepo else { return }
        let logRef = logStore
        await MainActor.run {
            self.isLoading = true
            self.statusMessage = "Pulling..."
            logRef.append("$ git pull", kind: .command)
        }
        do {
            try await gitService.pullLogged(at: repo.path) { text, isErr in
                logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
            }
            await loadRepoInfo()
            await MainActor.run {
                logRef.append("Pull complete", kind: .info)
                self.statusMessage = "Pull complete"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                logRef.append("Pull failed: \(error.localizedDescription)", kind: .stderr)
                self.statusMessage = "Pull failed"
                self.isLoading = false
            }
        }
    }

    // MARK: - Prune

    var pruneBranches: [String] = []
    var showPruneConfirmation = false

    func prune() async {
        guard let repo = selectedRepo else { return }
        let logRef = logStore
        await MainActor.run {
            self.isLoading = true
            self.statusMessage = "Pruning..."
            logRef.append("$ git fetch --prune", kind: .command)
        }
        do {
            try await gitService.pruneRemoteRefs(at: repo.path) { text, isErr in
                logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
            }
            let gone = try await gitService.findGoneBranches(at: repo.path)
            await loadRepoInfo()

            await MainActor.run {
                if gone.isEmpty {
                    logRef.append("Prune complete — no local branches to remove", kind: .info)
                    self.statusMessage = "Prune complete"
                    self.isLoading = false
                } else {
                    self.pruneBranches = gone
                    self.showPruneConfirmation = true
                    self.statusMessage = "Prune: \(gone.count) branch\(gone.count == 1 ? "" : "es") to delete"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                logRef.append("Prune failed: \(error.localizedDescription)", kind: .stderr)
                self.statusMessage = "Prune failed"
                self.isLoading = false
            }
        }
    }

    func confirmPruneDeletion() async {
        guard let repo = selectedRepo, !pruneBranches.isEmpty else { return }
        let logRef = logStore
        let branches = pruneBranches
        await MainActor.run {
            self.isLoading = true
            self.statusMessage = "Deleting branches..."
        }
        do {
            try await gitService.deleteLocalBranches(at: repo.path, branches: branches) { text, isErr in
                logRef.appendFromBackground(text, kind: isErr ? .stderr : .stdout)
            }
            await loadRepoInfo()
            await MainActor.run {
                logRef.append("Deleted \(branches.count) local branch\(branches.count == 1 ? "" : "es")", kind: .info)
                self.statusMessage = "Prune complete"
                self.isLoading = false
                self.pruneBranches = []
            }
        } catch {
            await MainActor.run {
                logRef.append("Delete failed: \(error.localizedDescription)", kind: .stderr)
                self.statusMessage = "Delete failed"
                self.isLoading = false
                self.pruneBranches = []
            }
        }
    }

    func cancelPrune() {
        pruneBranches = []
        statusMessage = "Prune complete (kept local branches)"
        isLoading = false
    }

    // MARK: - Create PR

    func openCreatePR() async {
        guard let repo = selectedRepo else { return }
        let remoteURL = try? await gitService.remoteURL(at: repo.path)
        guard let remote = remoteURL, !remote.isEmpty,
              let prURL = RemoteURLParser.createPRURL(remoteURL: remote, branch: currentBranch) else {
            await MainActor.run {
                self.errorMessage = "Could not determine PR URL"
            }
            return
        }
        _ = await MainActor.run {
            NSWorkspace.shared.open(prURL)
        }
    }

    // MARK: - Multi-Add Repos

    func requestMultiAdd(urls: [URL]) {
        multiAddURLs = urls
        showMultiAddConfirmation = true
    }

    func confirmMultiAddIndividually() async {
        let urls = multiAddURLs
        await MainActor.run {
            self.showMultiAddConfirmation = false
            self.multiAddURLs = []
        }
        for url in urls {
            await smartAdd(url: url)
        }
    }

    func confirmMultiAddAsGroup(name: String) async {
        let urls = multiAddURLs
        await MainActor.run {
            self.showMultiAddConfirmation = false
            self.multiAddURLs = []
        }

        let group = RepositoryGroup(name: name)
        await MainActor.run {
            self.addGroup(group)
        }

        for url in urls {
            let path = url.path
            let isRepo = await gitService.isGitRepository(at: path)

            if isRepo {
                let repo = Repository(name: url.lastPathComponent, path: path, groupID: group.id)
                await MainActor.run {
                    self.addRepository(repo)
                }
            } else {
                // Scan immediate children
                let children = await scanImmediateChildren(at: url)
                await MainActor.run {
                    for var repo in children {
                        repo.groupID = group.id
                        self.addRepository(repo)
                    }
                }
            }
        }
    }

    // MARK: - File Watcher

    private func setupFileWatcher(for repo: Repository) {
        fileWatcher?.stop()
        fileWatcher = FileWatcher(path: repo.path) {
            Task { @MainActor in
                NotificationCenter.default.post(name: .gitFilesChanged, object: nil)
            }
        }
        fileWatcher?.start()
    }

    // MARK: - Grouped Repos

    var ungroupedRepos: [Repository] {
        repositories.filter { $0.groupID == nil }
    }

    func repos(in group: RepositoryGroup) -> [Repository] {
        repositories.filter { $0.groupID == group.id }
    }
}

extension Notification.Name {
    static let gitFilesChanged = Notification.Name("gitFilesChanged")
}
