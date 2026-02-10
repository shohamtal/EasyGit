import Foundation

enum FileChangeStatus: String, Codable, Hashable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case conflicted = "C"
    case untracked = "?"
    case renamed = "R"

    var label: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .conflicted: return "C"
        case .untracked: return "?"
        case .renamed: return "R"
        }
    }
}

struct GitFileChange: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: FileChangeStatus

    var filename: String {
        (path as NSString).lastPathComponent
    }

    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir + "/"
    }
}
