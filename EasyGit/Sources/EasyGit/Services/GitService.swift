import Foundation

actor GitService {
    private func run(_ arguments: [String], at repoPath: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        process.environment = ProcessInfo.processInfo.environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GitError.commandFailed(errorStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }

    /// Streaming variant — calls `onOutput` with real-time lines from stdout/stderr
    func runLogged(
        _ arguments: [String],
        at repoPath: String,
        onOutput: @Sendable @escaping (String, Bool) -> Void  // (text, isStderr)
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let collector = OutputCollector()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            collector.appendStdout(data)
            if let str = String(data: data, encoding: .utf8) {
                onOutput(str, false)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            collector.appendStderr(data)
            if let str = String(data: data, encoding: .utf8) {
                onOutput(str, true)
            }
        }

        try process.run()
        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if process.terminationStatus != 0 {
            let errorStr = String(data: collector.stderrData, encoding: .utf8) ?? "Unknown error"
            throw GitError.commandFailed(errorStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: collector.stdoutData, encoding: .utf8) ?? ""
    }

    // MARK: - Status

    func status(at repoPath: String) async throws -> (staged: [GitFileChange], unstaged: [GitFileChange]) {
        let output = try await run(["status", "--porcelain=v1", "-u"], at: repoPath)
        return GitStatusParser.parse(output)
    }

    // MARK: - Diff

    func diff(at repoPath: String, file: String, staged: Bool) async throws -> String {
        var args = ["diff"]
        if staged {
            args.append("--cached")
        }
        args.append("--")
        args.append(file)
        return try await run(args, at: repoPath)
    }

    func diffForUntracked(at repoPath: String, file: String) async throws -> String {
        let fullPath = (repoPath as NSString).appendingPathComponent(file)
        let content = try String(contentsOfFile: fullPath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")
        var result = "--- /dev/null\n+++ b/\(file)\n@@ -0,0 +1,\(lines.count) @@\n"
        for line in lines {
            result += "+\(line)\n"
        }
        return result
    }

    // MARK: - Stage / Unstage

    func stageFile(at repoPath: String, file: String) async throws {
        _ = try await run(["add", "--", file], at: repoPath)
    }

    func unstageFile(at repoPath: String, file: String) async throws {
        _ = try await run(["restore", "--staged", "--", file], at: repoPath)
    }

    func stageAll(at repoPath: String) async throws {
        _ = try await run(["add", "-A"], at: repoPath)
    }

    func unstageAll(at repoPath: String) async throws {
        _ = try await run(["reset", "HEAD"], at: repoPath)
    }

    // MARK: - Revert

    func revertFiles(at repoPath: String, files: [String]) async throws {
        // For tracked files: git checkout -- file1 file2 ...
        // For untracked files: just delete them
        var trackedFiles: [String] = []
        var untrackedFiles: [String] = []

        let statusOutput = try await run(["status", "--porcelain=v1"], at: repoPath)
        let untrackedPaths = Set(
            statusOutput.components(separatedBy: "\n")
                .filter { $0.hasPrefix("??") }
                .map { String($0.dropFirst(3)) }
        )

        for file in files {
            if untrackedPaths.contains(file) {
                untrackedFiles.append(file)
            } else {
                trackedFiles.append(file)
            }
        }

        if !trackedFiles.isEmpty {
            _ = try await run(["checkout", "--"] + trackedFiles, at: repoPath)
        }

        for file in untrackedFiles {
            let fullPath = (repoPath as NSString).appendingPathComponent(file)
            try FileManager.default.removeItem(atPath: fullPath)
        }
    }

    // MARK: - Commit

    func commit(at repoPath: String, message: String) async throws {
        _ = try await run(["commit", "-m", message], at: repoPath)
    }

    // MARK: - Push / Pull

    func push(at repoPath: String) async throws {
        _ = try await run(["push"], at: repoPath)
    }

    func pull(at repoPath: String) async throws {
        _ = try await run(["pull"], at: repoPath)
    }

    func pushLogged(at repoPath: String, branch: String, onOutput: @Sendable @escaping (String, Bool) -> Void) async throws {
        // Check if current branch has an upstream
        let hasUpstream = (try? await run(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], at: repoPath)) != nil
        let args = hasUpstream ? ["push"] : ["push", "--set-upstream", "origin", branch]
        _ = try await runLogged(args, at: repoPath, onOutput: onOutput)
    }

    func pullLogged(at repoPath: String, onOutput: @Sendable @escaping (String, Bool) -> Void) async throws {
        _ = try await runLogged(["pull"], at: repoPath, onOutput: onOutput)
    }

    func commitLogged(at repoPath: String, message: String, onOutput: @Sendable @escaping (String, Bool) -> Void) async throws {
        _ = try await runLogged(["commit", "-m", message], at: repoPath, onOutput: onOutput)
    }

    func pruneRemoteRefs(at repoPath: String, onOutput: @Sendable @escaping (String, Bool) -> Void) async throws {
        _ = try await runLogged(["fetch", "--prune"], at: repoPath, onOutput: onOutput)
    }

    func deleteRemoteBranch(at repoPath: String, branch: String, onOutput: @Sendable @escaping (String, Bool) -> Void) async throws {
        onOutput("$ git push origin --delete \(branch)\n", false)
        _ = try await runLogged(["push", "origin", "--delete", branch], at: repoPath, onOutput: onOutput)
    }

    func deleteLocalBranches(at repoPath: String, branches: [String], onOutput: @Sendable @escaping (String, Bool) -> Void) async throws {
        // If current branch is in the delete list, switch to a safe branch first
        let current = try await currentBranch(at: repoPath)
        var didStash = false
        if branches.contains(current) {
            let allBranches = try await self.branches(at: repoPath)
            let safeBranch = allBranches.first(where: { $0.name == "master" })
                ?? allBranches.first(where: { $0.name == "main" })
                ?? allBranches.first(where: { !branches.contains($0.name) })
            if let safe = safeBranch {
                // Stash any uncommitted changes before switching
                let statusOut = try await run(["status", "--porcelain"], at: repoPath)
                if !statusOut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onOutput("$ git stash push -m \"EasyGit: auto-stash before prune\"\n", false)
                    _ = try await run(["stash", "push", "-m", "EasyGit: auto-stash before prune"], at: repoPath)
                    didStash = true
                }
                onOutput("$ git checkout \(safe.name)\n", false)
                _ = try await run(["checkout", safe.name], at: repoPath)
            }
        }

        for branch in branches {
            onOutput("$ git branch -D \(branch)\n", false)
            _ = try await run(["branch", "-D", branch], at: repoPath)
        }

        if didStash {
            onOutput("$ git stash pop\n", false)
            _ = try? await run(["stash", "pop"], at: repoPath)
        }
    }

    /// Returns local branch names whose remote tracking branch no longer exists (marked ": gone]" in git branch -vv)
    func findGoneBranches(at repoPath: String) async throws -> [String] {
        let output = try await run(["branch", "-vv"], at: repoPath)
        // Lines look like:
        //   test11   abc1234 [origin/test11: gone] some commit msg
        // * test222  3368a2a [origin/test222: gone] some commit msg
        //   master   def5678 [origin/master] some commit msg
        var gone: [String] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.contains(": gone]") else { continue }
            // Strip leading "* " for current branch
            let cleaned = trimmed.hasPrefix("*") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
            let branchName = cleaned.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
            if !branchName.isEmpty {
                gone.append(branchName)
            }
        }
        return gone
    }

    // MARK: - Partial Staging (line-level)

    func applyPatch(at repoPath: String, patch: String, reverse: Bool) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        var args = ["apply", "--cached", "--unidiff-zero"]
        if reverse { args.append("--reverse") }
        args.append("-")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        process.environment = ProcessInfo.processInfo.environment

        let stdinPipe = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        if let data = patch.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GitError.commandFailed(errorStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Branches

    func currentBranch(at repoPath: String) async throws -> String {
        let output = try await run(["rev-parse", "--abbrev-ref", "HEAD"], at: repoPath)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func branches(at repoPath: String) async throws -> [BranchInfo] {
        // Get local branches
        let localOutput = try await run(["branch", "--format=%(refname:short) %(HEAD)"], at: repoPath)
        var results: [BranchInfo] = []
        var localNames = Set<String>()

        for line in localOutput.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces)
            if parts.isEmpty { continue }
            let isCurrent = parts.hasSuffix("*")
            let name = parts.replacingOccurrences(of: " *", with: "").trimmingCharacters(in: .whitespaces)
            results.append(BranchInfo(name: name, isCurrent: isCurrent))
            localNames.insert(name)
        }

        // Get remote branches — add those without a local counterpart
        let remoteOutput = try await run(["branch", "-r", "--format=%(refname:short)"], at: repoPath)
        for line in remoteOutput.split(separator: "\n") {
            let full = line.trimmingCharacters(in: .whitespaces)
            if full.isEmpty || full.contains("HEAD") { continue }
            // Strip "origin/" prefix for display
            let shortName = full.hasPrefix("origin/") ? String(full.dropFirst(7)) : full
            if !localNames.contains(shortName) {
                results.append(BranchInfo(name: shortName, isRemote: true))
            }
        }

        return results
    }

    func createBranch(at repoPath: String, name: String) async throws {
        _ = try await run(["checkout", "-b", name], at: repoPath)
    }

    func checkout(at repoPath: String, branch: String) async throws {
        _ = try await run(["checkout", branch], at: repoPath)
    }

    // MARK: - Remote

    func remoteURL(at repoPath: String) async throws -> String? {
        let output = try? await run(["remote", "get-url", "origin"], at: repoPath)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validation

    func isGitRepository(at path: String) async -> Bool {
        do {
            _ = try await run(["rev-parse", "--git-dir"], at: path)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Protected Branch Detection

    private static let defaultProtectedNames: Set<String> = [
        "main", "master", "develop", "staging", "production", "release"
    ]

    func isProtectedBranch(at repoPath: String, branch: String) async -> Bool {
        // 1. Check common protected branch names
        let lower = branch.lowercased()
        if Self.defaultProtectedNames.contains(lower) || lower.hasPrefix("release/") {
            return true
        }

        // 2. Try GitHub API via gh CLI (if available)
        if let _ = try? await runExternal("/usr/local/bin/gh", arguments: ["api", "repos/{owner}/{repo}/branches/\(branch)/protection", "--jq", ".url"], at: repoPath) {
            return true
        }

        return false
    }

    /// Run a non-git external command (e.g. gh)
    private func runExternal(_ executablePath: String, arguments: [String], at repoPath: String) async throws -> String {
        let process = Process()
        // Try multiple paths for gh
        let paths = [executablePath, "/opt/homebrew/bin/gh", "/usr/bin/gh"]
        var found = false
        for p in paths {
            if FileManager.default.fileExists(atPath: p) {
                process.executableURL = URL(fileURLWithPath: p)
                found = true
                break
            }
        }
        guard found else { throw GitError.commandFailed("gh not found") }

        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        process.environment = ProcessInfo.processInfo.environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitError.commandFailed("exit \(process.terminationStatus)")
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Sensitive Data Detection

    struct SensitiveMatch: Sendable {
        let file: String
        let line: String
        let pattern: String
    }

    func scanUnpushedForSecrets(at repoPath: String) async -> [SensitiveMatch] {
        // Get diff of unpushed commits
        guard let diff = try? await run(["diff", "@{u}..HEAD"], at: repoPath) else {
            // No upstream — scan all staged content
            guard let diff = try? await run(["diff", "--cached"], at: repoPath) else {
                return []
            }
            return scanDiffForSecrets(diff)
        }
        return scanDiffForSecrets(diff)
    }

    private func scanDiffForSecrets(_ diff: String) -> [SensitiveMatch] {
        let patterns: [(String, String)] = [
            ("password\\s*[:=]\\s*[\"'][^\"']+[\"']", "Hardcoded password"),
            ("api[_-]?key\\s*[:=]\\s*[\"'][^\"']+[\"']", "API key"),
            ("secret\\s*[:=]\\s*[\"'][^\"']+[\"']", "Secret value"),
            ("token\\s*[:=]\\s*[\"'][^\"']+[\"']", "Token value"),
            ("AKIA[0-9A-Z]{16}", "AWS Access Key"),
            ("-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----", "Private key"),
            ("ghp_[0-9a-zA-Z]{36}", "GitHub personal access token"),
            ("sk-[0-9a-zA-Z]{32,}", "OpenAI/Stripe secret key"),
            ("Bearer\\s+[0-9a-zA-Z._\\-]{20,}", "Bearer token"),
        ]

        var matches: [SensitiveMatch] = []
        var currentFile = ""

        for rawLine in diff.components(separatedBy: "\n") {
            if rawLine.hasPrefix("+++ b/") {
                currentFile = String(rawLine.dropFirst(6))
                continue
            }

            // Only scan added lines
            guard rawLine.hasPrefix("+") && !rawLine.hasPrefix("+++") else { continue }
            let content = String(rawLine.dropFirst())

            for (pattern, label) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                    matches.append(SensitiveMatch(
                        file: currentFile,
                        line: content.trimmingCharacters(in: .whitespaces),
                        pattern: label
                    ))
                    break // One match per line is enough
                }
            }
        }

        return matches
    }
}

/// Thread-safe collector for process output data
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _stdout = Data()
    private var _stderr = Data()

    var stdoutData: Data { lock.withLock { _stdout } }
    var stderrData: Data { lock.withLock { _stderr } }

    func appendStdout(_ data: Data) { lock.withLock { _stdout.append(data) } }
    func appendStderr(_ data: Data) { lock.withLock { _stderr.append(data) } }
}

enum GitError: LocalizedError {
    case commandFailed(String)
    case notARepository

    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return msg
        case .notARepository: return "Not a git repository"
        }
    }
}
