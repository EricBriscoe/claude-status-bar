import Foundation

enum StatusProvider: String, CaseIterable {
    case claude
    case openai

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        }
    }

    var apiURL: URL {
        switch self {
        case .claude: return URL(string: "https://status.claude.com/api/v2/summary.json")!
        case .openai: return URL(string: "https://status.openai.com/api/v2/summary.json")!
        }
    }

    var pageURL: URL {
        switch self {
        case .claude: return URL(string: "https://status.claude.com")!
        case .openai: return URL(string: "https://status.openai.com")!
        }
    }

    private static let defaultsKey = "statusProvider"

    static var current: StatusProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let provider = StatusProvider(rawValue: raw) else {
                return .claude
            }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}
