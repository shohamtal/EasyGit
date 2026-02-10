import Foundation

enum RemoteURLParser {
    struct RemoteInfo {
        let host: String
        let owner: String
        let repo: String
    }

    static func parse(_ remoteURL: String) -> RemoteInfo? {
        // SSH format: git@github.com:owner/repo.git
        if remoteURL.contains("@") && remoteURL.contains(":") {
            let parts = remoteURL.split(separator: ":")
            guard parts.count == 2 else { return nil }
            let hostPart = String(parts[0]).replacingOccurrences(of: "git@", with: "")
            let pathPart = String(parts[1]).replacingOccurrences(of: ".git", with: "")
            let pathComponents = pathPart.split(separator: "/")
            guard pathComponents.count >= 2 else { return nil }
            return RemoteInfo(
                host: hostPart,
                owner: String(pathComponents[0]),
                repo: String(pathComponents[1])
            )
        }

        // HTTPS format: https://github.com/owner/repo.git
        guard let url = URL(string: remoteURL),
              let host = url.host else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else { return nil }

        return RemoteInfo(
            host: host,
            owner: pathComponents[0],
            repo: pathComponents[1].replacingOccurrences(of: ".git", with: "")
        )
    }

    static func createPRURL(remoteURL: String, branch: String) -> URL? {
        guard let info = parse(remoteURL) else { return nil }

        if info.host.contains("github.com") {
            return URL(string: "https://github.com/\(info.owner)/\(info.repo)/compare/\(branch)?expand=1")
        } else if info.host.contains("bitbucket.org") {
            return URL(string: "https://bitbucket.org/\(info.owner)/\(info.repo)/pull-requests/new?source=\(branch)")
        } else if info.host.contains("gitlab") {
            return URL(string: "https://\(info.host)/\(info.owner)/\(info.repo)/-/merge_requests/new?merge_request[source_branch]=\(branch)")
        }

        return nil
    }
}
