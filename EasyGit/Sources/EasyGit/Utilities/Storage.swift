import Foundation

enum Storage {
    private static let reposKey = "gitdesk.repositories"
    private static let groupsKey = "gitdesk.groups"
    private static let selectedRepoKey = "gitdesk.selectedRepoPath"

    static func loadRepositories() -> [Repository] {
        guard let data = UserDefaults.standard.data(forKey: reposKey),
              let repos = try? JSONDecoder().decode([Repository].self, from: data) else {
            return []
        }
        return repos
    }

    static func saveRepositories(_ repos: [Repository]) {
        if let data = try? JSONEncoder().encode(repos) {
            UserDefaults.standard.set(data, forKey: reposKey)
        }
    }

    static func loadGroups() -> [RepositoryGroup] {
        guard let data = UserDefaults.standard.data(forKey: groupsKey),
              let groups = try? JSONDecoder().decode([RepositoryGroup].self, from: data) else {
            return []
        }
        return groups
    }

    static func saveGroups(_ groups: [RepositoryGroup]) {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    static func saveSelectedRepoPath(_ path: String?) {
        UserDefaults.standard.set(path, forKey: selectedRepoKey)
    }

    static func loadSelectedRepoPath() -> String? {
        UserDefaults.standard.string(forKey: selectedRepoKey)
    }
}
