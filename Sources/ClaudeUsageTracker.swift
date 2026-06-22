import Foundation
import CommonCrypto
import SQLite3

class ClaudeUsageTracker {
    enum Availability { case unchecked, available, noClaude, authError(String), error(String) }

    private(set) var usageData: ClaudeUsageResponse?
    private(set) var availability: Availability = .unchecked
    var onUpdate: (() -> Void)?

    private var timer: Timer?
    private var derivedKey: Data?
    private static let pollInterval: TimeInterval = 120
    private static let showPlanUsageKey = "showClaudePlanUsage"

    private static let claudeDataDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude")

    // Ephemeral session: no disk cache, no persistent cookie/credential storage
    private static let apiSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        return URLSession(configuration: config, delegate: RedirectBlocker(), delegateQueue: nil)
    }()

    static var showPlanUsage: Bool {
        get { UserDefaults.standard.bool(forKey: showPlanUsageKey) }
        set { UserDefaults.standard.set(newValue, forKey: showPlanUsageKey) }
    }

    init() {
        guard Self.showPlanUsage else { return }
        start()
    }

    deinit { timer?.invalidate() }

    func start() {
        timer?.invalidate()
        fetchUsage()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        usageData = nil
        availability = .unchecked
        onUpdate?()
    }

    func refresh() {
        guard Self.showPlanUsage else { return }
        fetchUsage()
    }

    private func fetchUsage() {
        Task {
            do {
                let orgId = try Self.readOrgId()
                let cookies = try readCookies()
                let cookieHeader = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")

                let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
                var request = URLRequest(url: url)
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
                request.setValue("application/json", forHTTPHeaderField: "Accept")

                let (data, response) = try await Self.apiSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClaudeUsageError.requestFailed("No HTTP response")
                }

                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 403 {
                        throw ClaudeUsageError.authExpired
                    }
                    throw ClaudeUsageError.requestFailed("HTTP \(httpResponse.statusCode)")
                }

                let decoded = try JSONDecoder.snakeCase.decode(ClaudeUsageResponse.self, from: data)

                await MainActor.run {
                    self.usageData = decoded
                    self.availability = .available
                    self.onUpdate?()
                }
            } catch let error as ClaudeUsageError {
                await MainActor.run {
                    switch error {
                    case .claudeNotInstalled:
                        self.availability = .noClaude
                    case .authExpired:
                        self.availability = .authError("Session expired. Open Claude to refresh")
                    default:
                        self.availability = .error(error.localizedDescription)
                    }
                    self.onUpdate?()
                }
            } catch {
                await MainActor.run {
                    self.availability = .error(error.localizedDescription)
                    self.onUpdate?()
                }
            }
        }
    }

    private static func readOrgId() throws -> String {
        let path = claudeDataDir.appendingPathComponent("bridge-state.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ClaudeUsageError.claudeNotInstalled
        }
        let data = try Data(contentsOf: path)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let firstKey = json.keys.first,
              let orgId = firstKey.components(separatedBy: ":").first,
              UUID(uuidString: orgId) != nil else {
            throw ClaudeUsageError.parseError("Could not read org ID")
        }
        return orgId
    }

    private func readCookies() throws -> [String: String] {
        let key = try getDerivedKey()
        let dbPath = Self.claudeDataDir.appendingPathComponent("Cookies").path

        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw ClaudeUsageError.claudeNotInstalled
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            throw ClaudeUsageError.dbError("Cannot open cookie database")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2000)

        var stmt: OpaquePointer?
        let sql = "SELECT name, encrypted_value FROM cookies WHERE host_key LIKE '%claude.ai%'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ClaudeUsageError.dbError("Cannot query cookies")
        }
        defer { sqlite3_finalize(stmt) }

        var cookies: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let namePtr = sqlite3_column_text(stmt, 0) else { continue }
            let name = String(cString: namePtr)
            let blobPtr = sqlite3_column_blob(stmt, 1)
            let blobLen = sqlite3_column_bytes(stmt, 1)
            guard let blobPtr, blobLen > 0 else { continue }
            let encrypted = Data(bytes: blobPtr, count: Int(blobLen))

            if let value = decrypt(encrypted, key: key) {
                cookies[name] = value
            }
        }

        guard cookies["sessionKey"] != nil else {
            throw ClaudeUsageError.authExpired
        }
        return cookies
    }

    private func getDerivedKey() throws -> Data {
        if let cached = derivedKey { return cached }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Safe Storage", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ClaudeUsageError.keychainDenied
        }

        let passwordData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let password = String(data: passwordData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !password.isEmpty else {
            throw ClaudeUsageError.keychainDenied
        }

        let salt = "saltysalt"
        var key = Data(count: 16)
        let status = key.withUnsafeMutableBytes { keyPtr in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, password.utf8.count,
                salt, salt.utf8.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                1003,
                keyPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), 16
            )
        }

        guard status == kCCSuccess else {
            throw ClaudeUsageError.cryptoError("Key derivation failed")
        }

        derivedKey = key
        return key
    }

    private func decrypt(_ encrypted: Data, key: Data) -> String? {
        guard encrypted.count > 3,
              encrypted[0] == 0x76, encrypted[1] == 0x31, encrypted[2] == 0x30 else { return nil }

        let ciphertext = encrypted.subdata(in: 3..<encrypted.count)
        let iv = Data(repeating: 0x20, count: 16)
        let bufferSize = ciphertext.count + kCCBlockSizeAES128
        var output = Data(count: bufferSize)
        var outputLength = 0

        let status = output.withUnsafeMutableBytes { outPtr in
            key.withUnsafeBytes { keyPtr in
                iv.withUnsafeBytes { ivPtr in
                    ciphertext.withUnsafeBytes { dataPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            0,
                            keyPtr.baseAddress!, key.count,
                            ivPtr.baseAddress!,
                            dataPtr.baseAddress!, ciphertext.count,
                            outPtr.baseAddress!, bufferSize,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == CCCryptorStatus(kCCSuccess), outputLength > 0 else { return nil }
        var decrypted = output.prefix(outputLength)

        if let last = decrypted.last, last >= 1, last <= 16,
           decrypted.suffix(Int(last)).allSatisfy({ $0 == last }) {
            decrypted = decrypted.prefix(decrypted.count - Int(last))
        }

        let text = String(decoding: decrypted, as: UTF8.self)

        // CBC first block is garbled due to unknown IV; find clean content start
        guard let range = text.range(of: #"[a-zA-Z0-9][a-zA-Z0-9._+/=\-]{3,}"#, options: .regularExpression) else {
            return nil
        }
        return String(text[range.lowerBound...])
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let resetTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    static func resetDescription(for isoDate: String) -> String {
        guard let date = isoFormatter.date(from: isoDate) else { return "" }

        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "resetting…" }
        if interval < 3600 { return "resets in \(Int(interval / 60)) min" }
        if interval < 86400 { return "resets in \(Int(interval / 3600)) hr" }
        return "resets \(resetTimeFormatter.string(from: date))"
    }
}

// Blocks redirects to non-claude.ai domains to prevent cookie leakage
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(request.url?.host?.hasSuffix("claude.ai") == true ? request : nil)
    }
}

private enum ClaudeUsageError: LocalizedError {
    case claudeNotInstalled
    case keychainDenied
    case authExpired
    case dbError(String)
    case parseError(String)
    case cryptoError(String)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .claudeNotInstalled: return "Claude desktop app not found"
        case .keychainDenied: return "Keychain access denied"
        case .authExpired: return "Session expired. Open Claude to refresh"
        case .dbError(let msg), .parseError(let msg),
             .cryptoError(let msg), .requestFailed(let msg):
            return msg
        }
    }
}
