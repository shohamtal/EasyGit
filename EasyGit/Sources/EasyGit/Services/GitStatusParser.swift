import Foundation

enum GitStatusParser {
    static func parse(_ output: String) -> (staged: [GitFileChange], unstaged: [GitFileChange]) {
        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []

        let lines = output.components(separatedBy: "\n")

        for line in lines {
            guard line.count >= 3 else { continue }

            let indexStatus = line[line.startIndex]
            let workTreeStatus = line[line.index(line.startIndex, offsetBy: 1)]
            let path = String(line.dropFirst(3))

            // Staged changes (index column)
            if let status = mapStatus(indexStatus) {
                staged.append(GitFileChange(path: path, status: status))
            }

            // Unstaged changes (work tree column)
            if workTreeStatus == "?" {
                // Untracked file
                unstaged.append(GitFileChange(path: path, status: .untracked))
            } else if let status = mapWorkTreeStatus(workTreeStatus, indexStatus: indexStatus) {
                unstaged.append(GitFileChange(path: path, status: status))
            }
        }

        return (
            staged.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending },
            unstaged.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
        )
    }

    private static func mapStatus(_ c: Character) -> FileChangeStatus? {
        switch c {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "U": return .conflicted
        default: return nil
        }
    }

    private static func mapWorkTreeStatus(_ c: Character, indexStatus: Character) -> FileChangeStatus? {
        switch c {
        case "M": return .modified
        case "D": return .deleted
        case "U": return .conflicted
        case "A" where indexStatus == "A": return .conflicted // both added
        default: return nil
        }
    }
}
