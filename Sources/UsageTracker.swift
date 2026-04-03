import Foundation

class UsageTracker {
    enum Availability { case unchecked, available, notInstalled, error(String) }

    private(set) var usageData: UsageData?
    private(set) var availability: Availability = .unchecked
    var onUpdate: (() -> Void)?

    private var timer: Timer?
    private var resolvedExecutable: URL?
    private var useBunx = false
    private var cachedShellPath: String?
    private static let pollInterval: TimeInterval = 300

    private static let showTodayKey = "showUsageToday"
    private static let show90dKey = "showUsage90d"

    static var showToday: Bool {
        get { UserDefaults.standard.bool(forKey: showTodayKey) }
        set { UserDefaults.standard.set(newValue, forKey: showTodayKey) }
    }

    static var show90d: Bool {
        get { UserDefaults.standard.bool(forKey: show90dKey) }
        set { UserDefaults.standard.set(newValue, forKey: show90dKey) }
    }

    static var isEnabled: Bool { showToday || show90d }

    init() {
        guard Self.isEnabled else { return }
        start()
    }

    deinit {
        timer?.invalidate()
    }

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
        guard Self.isEnabled else { return }
        fetchUsage()
    }

    private static let packages: [(pkg: String, bunxPkg: String)] = [
        ("ccusage@latest", "ccusage"),
        ("@ccusage/codex@latest", "@ccusage/codex"),
    ]

    private func fetchUsage() {
        Task {
            do {
                let executable = try await resolveExecutable()
                let sinceDate = Self.dateString(daysAgo: 90)
                let todayStrs = Self.todayStrings()

                var perProvider: [(costToday: Double, cost90d: Double, tokensToday: Int, tokens90d: Int)] = []

                for pkg in Self.packages {
                    let args = [useBunx ? pkg.bunxPkg : pkg.pkg, "daily", "--json", "--since", sinceDate]
                    guard let output = try? await runProcess(executable: executable, arguments: args),
                          let response = try? JSONDecoder().decode(CcusageResponse.self, from: output) else {
                        perProvider.append((0, 0, 0, 0))
                        continue
                    }

                    let todayEntry = response.daily.last { entry in todayStrs.contains(entry.date) }
                    perProvider.append((
                        costToday: todayEntry?.cost ?? 0,
                        cost90d: response.totals?.cost ?? 0,
                        tokensToday: todayEntry?.totalTokens ?? 0,
                        tokens90d: response.totals?.totalTokens ?? 0
                    ))
                }

                let empty = (costToday: 0.0, cost90d: 0.0, tokensToday: 0, tokens90d: 0)
                let claude = perProvider.indices.contains(0) ? perProvider[0] : empty
                let codex = perProvider.indices.contains(1) ? perProvider[1] : empty

                let data = UsageData(
                    claude: .init(costToday: claude.costToday, cost90d: claude.cost90d,
                                  tokensToday: claude.tokensToday, tokens90d: claude.tokens90d),
                    codex: .init(costToday: codex.costToday, cost90d: codex.cost90d,
                                 tokensToday: codex.tokensToday, tokens90d: codex.tokens90d)
                )

                await MainActor.run {
                    self.usageData = data
                    self.availability = .available
                    self.onUpdate?()
                }
            } catch {
                await MainActor.run {
                    if case .notInstalled = self.availability { return }
                    self.availability = .error(error.localizedDescription)
                    self.onUpdate?()
                }
            }
        }
    }

    private func resolveExecutable() async throws -> URL {
        if let cached = resolvedExecutable { return cached }

        let shellPath = try await getShellPath()
        let dirs = shellPath.split(separator: ":").map(String.init)

        for (name, isBunx) in [("npx", false), ("bunx", true)] {
            for dir in dirs {
                let path = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: path) {
                    let url = URL(fileURLWithPath: path)
                    resolvedExecutable = url
                    useBunx = isBunx
                    return url
                }
            }
        }

        await MainActor.run {
            self.availability = .notInstalled
            self.onUpdate?()
        }
        throw UsageError.notInstalled
    }

    private func getShellPath() async throws -> String {
        if let cached = cachedShellPath { return cached }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "echo $PATH"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let path: String = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: result)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        cachedShellPath = path
        return path
    }

    private func runProcess(executable: URL, arguments: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        if let shellPath = cachedShellPath {
            env["PATH"] = shellPath
        }
        process.environment = env

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: UsageError.processFailure(proc.terminationStatus))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
                if process.isRunning { process.terminate() }
            }
        }
    }

    private static func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func todayStrings() -> [String] {
        let now = Date()
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        let english = DateFormatter()
        english.dateFormat = "MMM dd, yyyy"
        english.locale = Locale(identifier: "en_US")
        return [iso.string(from: now), english.string(from: now)]
    }
}

private enum UsageError: LocalizedError {
    case notInstalled
    case processFailure(Int32)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "ccusage not found"
        case .processFailure(let code): return "ccusage exited with code \(code)"
        }
    }
}
