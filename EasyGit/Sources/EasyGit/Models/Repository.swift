import Foundation

struct Repository: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var groupID: UUID?

    init(id: UUID = UUID(), name: String, path: String, groupID: UUID? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.groupID = groupID
    }
}
