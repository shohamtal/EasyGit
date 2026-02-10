import Foundation

struct BranchInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isCurrent: Bool
    let isRemote: Bool

    init(name: String, isCurrent: Bool = false, isRemote: Bool = false) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
    }
}
