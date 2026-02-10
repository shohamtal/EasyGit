import Foundation

@Observable
final class DiffViewModel {
    var currentDiff: FileDiff?
    var isLoading: Bool = false
    var filename: String = ""
    var isStaged: Bool = false

    // Line selection
    var selectedLineIDs: Set<UUID> = []

    // Stored for building partial patches
    private(set) var rawDiff: String = ""
    private(set) var filePath: String = ""
    private(set) var repoPath: String = ""

    private let gitService: GitService

    init(gitService: GitService) {
        self.gitService = gitService
    }

    func loadDiff(repoPath: String, file: GitFileChange, staged: Bool) async {
        await MainActor.run {
            self.isLoading = true
            self.filename = file.path
            self.filePath = file.path
            self.repoPath = repoPath
            self.isStaged = staged
            self.selectedLineIDs = []
        }

        do {
            let rawDiff: String
            if file.status == .untracked {
                rawDiff = try await gitService.diffForUntracked(at: repoPath, file: file.path)
            } else {
                rawDiff = try await gitService.diff(at: repoPath, file: file.path, staged: staged)
            }
            let parsed = GitDiffParser.parse(rawDiff)
            await MainActor.run {
                self.rawDiff = rawDiff
                self.currentDiff = parsed
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.rawDiff = ""
                self.currentDiff = nil
                self.isLoading = false
            }
        }
    }

    func clear() {
        currentDiff = nil
        filename = ""
        rawDiff = ""
        filePath = ""
        repoPath = ""
        selectedLineIDs = []
    }

    // MARK: - Line Selection

    var allLines: [DiffLine] {
        currentDiff?.hunks.flatMap(\.lines) ?? []
    }

    var selectedLines: [DiffLine] {
        allLines.filter { selectedLineIDs.contains($0.id) }
    }

    var canStageLines: Bool {
        !isStaged && !selectedLineIDs.isEmpty
    }

    var canUnstageLines: Bool {
        isStaged && !selectedLineIDs.isEmpty
    }

    // MARK: - Stage / Unstage Selected Lines

    func stageSelectedLines() async throws {
        guard !selectedLineIDs.isEmpty, let diff = currentDiff else { return }
        let patch = buildPartialPatch(from: diff, selectedIDs: selectedLineIDs, forStaging: true)
        try await gitService.applyPatch(at: repoPath, patch: patch, reverse: false)
    }

    func unstageSelectedLines() async throws {
        guard !selectedLineIDs.isEmpty, let diff = currentDiff else { return }
        let patch = buildPartialPatch(from: diff, selectedIDs: selectedLineIDs, forStaging: false)
        try await gitService.applyPatch(at: repoPath, patch: patch, reverse: true)
    }

    // MARK: - Partial Patch Builder

    private func buildPartialPatch(from diff: FileDiff, selectedIDs: Set<UUID>, forStaging: Bool) -> String {
        var result = "diff --git a/\(filePath) b/\(filePath)\n"
        result += "--- a/\(filePath)\n"
        result += "+++ b/\(filePath)\n"

        for hunk in diff.hunks {
            let hunkLines = hunk.lines.filter { $0.type != .header }
            let hasSelected = hunkLines.contains { selectedIDs.contains($0.id) }
            guard hasSelected else { continue }

            var patchLines: [String] = []
            var oldCount = 0
            var newCount = 0

            let headerNums = parseHunkHeader(hunk.header)
            let oldStart = headerNums.oldStart
            let newStart = headerNums.newStart

            for line in hunkLines {
                let isSelected = selectedIDs.contains(line.id)

                switch line.type {
                case .context:
                    patchLines.append(" \(line.content)")
                    oldCount += 1
                    newCount += 1
                case .addition:
                    if isSelected {
                        patchLines.append("+\(line.content)")
                        newCount += 1
                    } else if forStaging {
                        // Staging: skip unselected additions (don't stage them)
                    } else {
                        // Unstaging: unselected additions become context (keep them staged)
                        patchLines.append(" \(line.content)")
                        oldCount += 1
                        newCount += 1
                    }
                case .removal:
                    if isSelected {
                        patchLines.append("-\(line.content)")
                        oldCount += 1
                    } else if forStaging {
                        // Staging: unselected removals become context (don't stage them)
                        patchLines.append(" \(line.content)")
                        oldCount += 1
                        newCount += 1
                    } else {
                        // Unstaging: skip unselected removals (keep them staged)
                    }
                case .header:
                    break
                }
            }

            guard !patchLines.isEmpty else { continue }

            result += "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@\n"
            for pl in patchLines {
                result += pl + "\n"
            }
        }

        return result
    }

    private func parseHunkHeader(_ header: String) -> (oldStart: Int, newStart: Int) {
        let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)) else {
            return (1, 1)
        }
        let oldStart = Int(header[Range(match.range(at: 1), in: header)!]) ?? 1
        let newStart = Int(header[Range(match.range(at: 2), in: header)!]) ?? 1
        return (oldStart, newStart)
    }
}
