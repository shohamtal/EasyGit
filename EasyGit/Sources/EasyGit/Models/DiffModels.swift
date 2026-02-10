import Foundation

enum DiffLineType: Hashable {
    case context
    case addition
    case removal
    case header
}

struct DiffLine: Identifiable, Hashable {
    let id = UUID()
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let type: DiffLineType
    let content: String
}

struct DiffHunk: Identifiable, Hashable {
    let id = UUID()
    let header: String
    let lines: [DiffLine]
}

struct FileDiff {
    let filename: String
    let hunks: [DiffHunk]

    var isEmpty: Bool { hunks.isEmpty }
}
