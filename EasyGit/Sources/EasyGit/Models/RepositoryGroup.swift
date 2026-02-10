import Foundation

struct RepositoryGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String?           // Parent directory path — enables rescanning
    var workspacePath: String?  // .code-workspace file path — enables rescan from workspace

    init(id: UUID = UUID(), name: String, path: String? = nil, workspacePath: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.workspacePath = workspacePath
    }

    var isRescannable: Bool {
        path != nil || workspacePath != nil
    }
}
