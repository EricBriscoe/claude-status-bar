import Cocoa

class UpdateChecker {
    static let appVersion = "1.1.0"

    private static let releasesURL = URL(
        string: "https://api.github.com/repos/EricBriscoe/claude-status-bar/releases/latest"
    )!
    private static let checkInterval: TimeInterval = 6 * 60 * 60
    private static let skippedVersionKey = "skippedVersion"

    private var timer: Timer?

    init() {
        check(silent: true)
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.check(silent: true)
        }
    }

    deinit {
        timer?.invalidate()
    }

    func check(silent: Bool = false) {
        Task {
            guard let release = try? await fetchLatestRelease() else {
                if !silent { await showNoUpdateAlert() }
                return
            }

            let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            guard isNewer(latest, than: Self.appVersion) else {
                if !silent { await showNoUpdateAlert() }
                return
            }

            if silent {
                let skipped = UserDefaults.standard.string(forKey: Self.skippedVersionKey)
                if skipped == latest { return }
            }

            await showUpdateAlert(version: latest, name: release.name ?? latest, url: release.htmlUrl)
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        for idx in 0..<max(remoteParts.count, localParts.count) {
            let rem = idx < remoteParts.count ? remoteParts[idx] : 0
            let loc = idx < localParts.count ? localParts[idx] : 0
            if rem != loc { return rem > loc }
        }
        return false
    }

    @MainActor
    private func showUpdateAlert(version: String, name: String, url: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "\(name) is available. You're currently on v\(Self.appVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let downloadURL = URL(string: url) {
                NSWorkspace.shared.open(downloadURL)
            }
        case .alertSecondButtonReturn:
            UserDefaults.standard.set(version, forKey: Self.skippedVersionKey)
        default:
            break
        }
    }

    @MainActor
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "Version \(Self.appVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let htmlUrl: String
}
