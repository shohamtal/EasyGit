import Foundation

enum GitDiffParser {
    static func parse(_ rawDiff: String) -> FileDiff {
        let lines = rawDiff.components(separatedBy: "\n")
        var hunks: [DiffHunk] = []
        var currentLines: [DiffLine] = []
        var currentHeader = ""
        var oldLine = 0
        var newLine = 0
        var filename = ""

        for line in lines {
            // Extract filename
            if line.hasPrefix("+++ b/") {
                filename = String(line.dropFirst(6))
                continue
            }
            if line.hasPrefix("--- ") || line.hasPrefix("+++ ") || line.hasPrefix("diff ") || line.hasPrefix("index ") {
                continue
            }

            // Hunk header
            if line.hasPrefix("@@") {
                // Save previous hunk
                if !currentLines.isEmpty {
                    hunks.append(DiffHunk(header: currentHeader, lines: currentLines))
                    currentLines = []
                }

                currentHeader = line
                let numbers = parseHunkHeader(line)
                oldLine = numbers.oldStart
                newLine = numbers.newStart

                currentLines.append(DiffLine(
                    oldLineNumber: nil,
                    newLineNumber: nil,
                    type: .header,
                    content: line
                ))
                continue
            }

            if line.hasPrefix("+") {
                currentLines.append(DiffLine(
                    oldLineNumber: nil,
                    newLineNumber: newLine,
                    type: .addition,
                    content: String(line.dropFirst())
                ))
                newLine += 1
            } else if line.hasPrefix("-") {
                currentLines.append(DiffLine(
                    oldLineNumber: oldLine,
                    newLineNumber: nil,
                    type: .removal,
                    content: String(line.dropFirst())
                ))
                oldLine += 1
            } else if line.hasPrefix(" ") || (!line.hasPrefix("\\") && !line.isEmpty && currentHeader != "") {
                let content = line.hasPrefix(" ") ? String(line.dropFirst()) : line
                currentLines.append(DiffLine(
                    oldLineNumber: oldLine,
                    newLineNumber: newLine,
                    type: .context,
                    content: content
                ))
                oldLine += 1
                newLine += 1
            }
        }

        // Save last hunk
        if !currentLines.isEmpty {
            hunks.append(DiffHunk(header: currentHeader, lines: currentLines))
        }

        return FileDiff(filename: filename, hunks: hunks)
    }

    private static func parseHunkHeader(_ header: String) -> (oldStart: Int, newStart: Int) {
        // @@ -oldStart,oldCount +newStart,newCount @@
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
