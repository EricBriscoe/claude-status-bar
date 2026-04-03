import Cocoa
import ServiceManagement

private enum ComponentStatus {
    case operational, degraded, partialOutage, majorOutage, maintenance, unknown

    init(_ raw: String) {
        switch raw {
        case "operational": self = .operational
        case "degraded_performance": self = .degraded
        case "partial_outage": self = .partialOutage
        case "major_outage": self = .majorOutage
        case "under_maintenance": self = .maintenance
        default: self = .unknown
        }
    }

    var dot: String {
        switch self {
        case .operational: return "🟢"
        case .degraded: return "🟡"
        case .partialOutage: return "🟠"
        case .majorOutage: return "🔴"
        case .maintenance: return "🔵"
        case .unknown: return "⚪"
        }
    }

    var label: String {
        switch self {
        case .operational: return "Operational"
        case .degraded: return "Degraded"
        case .partialOutage: return "Partial Outage"
        case .majorOutage: return "Major Outage"
        case .maintenance: return "Maintenance"
        case .unknown: return "Unknown"
        }
    }
}

class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let updateChecker = UpdateChecker()
    private let usageTracker = UsageTracker()
    private var summary: StatusSummary?
    private var fetchError: String?
    private var lastChecked: Date?
    private var timer: Timer?

    private static let pollInterval: TimeInterval = 60
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.image = Self.dotImage(color: .systemGray)
        statusItem.button?.imagePosition = .imageLeft
        statusItem.button?.toolTip = "\(StatusProvider.current.displayName) Status"
        usageTracker.onUpdate = { [weak self] in self?.updateUI() }
        rebuildMenu()
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func fetch() {
        let url = StatusProvider.current.apiURL
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder.snakeCase.decode(StatusSummary.self, from: data)
                await MainActor.run {
                    self.summary = response
                    self.fetchError = nil
                    self.lastChecked = Date()
                    self.updateUI()
                }
            } catch {
                await MainActor.run {
                    self.fetchError = error.localizedDescription
                    self.lastChecked = Date()
                    self.updateUI()
                }
            }
        }
    }

    private func switchProvider(_ provider: StatusProvider) {
        StatusProvider.current = provider
        summary = nil
        fetchError = nil
        lastChecked = nil
        statusItem.button?.image = Self.dotImage(color: .systemGray)
        statusItem.button?.toolTip = "\(provider.displayName) Status"
        rebuildMenu()
        fetch()
    }

    private func updateUI() {
        let color: NSColor = switch summary?.status.indicator {
        case "none": .systemGreen
        case "minor": .systemYellow
        case "major": .systemOrange
        case "critical": .systemRed
        default: .systemGray
        }
        statusItem.button?.image = Self.dotImage(color: color)
        statusItem.button?.title = usageBarTitle()
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let provider = StatusProvider.current

        if let summary {
            addLabel(to: menu, title: "\(provider.displayName): \(summary.status.description)", bold: true)
            menu.addItem(.separator())

            for component in summary.components {
                let status = ComponentStatus(component.status)
                addLabel(to: menu, title: "\(status.dot)  \(component.name) — \(status.label)")
            }

            if !summary.incidents.isEmpty {
                menu.addItem(.separator())
                addLabel(to: menu, title: "Active Incidents", bold: true)
                for incident in summary.incidents {
                    addLabel(to: menu, title: "\u{26A0} \(incident.name) (\(incident.impact))")
                    if let update = incident.incidentUpdates?.first {
                        let text = String(update.body.prefix(100))
                        addLabel(to: menu, title: "   \(text)\(update.body.count > 100 ? "…" : "")")
                    }
                }
            }
        } else if let fetchError {
            addLabel(to: menu, title: "Error: \(fetchError)")
        } else {
            addLabel(to: menu, title: "Loading…")
        }

        if UsageTracker.isEnabled {
            menu.addItem(.separator())
            addUsageSection(to: menu)
        }

        menu.addItem(.separator())

        if let lastChecked {
            addLabel(to: menu, title: "Updated \(Self.timeFormatter.string(from: lastChecked))")
        }

        addAction(to: menu, title: "Refresh", key: "r", action: #selector(handleRefresh))
        menu.addItem(.separator())

        for candidate in StatusProvider.allCases {
            let action = #selector(handleSwitchProvider(_:))
            let item = NSMenuItem(title: candidate.displayName, action: action, keyEquivalent: "")
            item.target = self
            item.state = candidate == provider ? .on : .off
            item.representedObject = candidate.rawValue
            menu.addItem(item)
        }

        menu.addItem(.separator())
        addAction(to: menu, title: "Open Status Page", key: "o", action: #selector(handleOpenPage))
        addAction(to: menu, title: "Check for Updates", key: "u", action: #selector(handleCheckUpdate))

        addToggle(to: menu, title: "Show Today's Usage", isOn: UsageTracker.showToday, action: #selector(handleToggleUsageToday))
        addToggle(to: menu, title: "Show 90d Usage", isOn: UsageTracker.show90d, action: #selector(handleToggleUsage90d))
        addToggle(to: menu, title: "Open at Login", isOn: SMAppService.mainApp.status == .enabled, action: #selector(handleToggleLogin))

        menu.addItem(.separator())
        addAction(to: menu, title: "Quit", key: "q", action: #selector(handleQuit))

        statusItem.menu = menu
    }

    private func addLabel(to menu: NSMenu, title: String, bold: Bool = false) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if bold {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
            )
        }
        menu.addItem(item)
    }

    private func addAction(to menu: NSMenu, title: String, key: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func addToggle(to menu: NSMenu, title: String, isOn: Bool, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        menu.addItem(item)
    }

    @objc private func handleRefresh() {
        fetch()
        usageTracker.refresh()
    }

    @objc private func handleOpenPage() {
        NSWorkspace.shared.open(StatusProvider.current.pageURL)
    }

    @objc private func handleSwitchProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = StatusProvider(rawValue: raw) else { return }
        switchProvider(provider)
    }

    @objc private func handleCheckUpdate() {
        updateChecker.check()
    }

    @objc private func handleToggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {}
        rebuildMenu()
    }

    @objc private func handleToggleUsageToday() {
        UsageTracker.showToday.toggle()
        syncUsageTracker()
    }

    @objc private func handleToggleUsage90d() {
        UsageTracker.show90d.toggle()
        syncUsageTracker()
    }

    private func syncUsageTracker() {
        if UsageTracker.isEnabled {
            usageTracker.start()
        } else {
            usageTracker.stop()
        }
        updateUI()
    }

    @objc private func handleQuit() { NSApp.terminate(nil) }

    private func addUsageSection(to menu: NSMenu) {
        switch usageTracker.availability {
        case .notInstalled:
            addLabel(to: menu, title: "\u{26A0} Requires Node.js or Bun")
            addLabel(to: menu, title: "  npx ccusage@latest daily")
            addLabel(to: menu, title: "  npx @ccusage/codex@latest daily")
        case .error(let msg):
            addLabel(to: menu, title: "\u{26A0} Usage: \(msg)")
        case .unchecked:
            addLabel(to: menu, title: "Loading usage…")
        case .available:
            guard let data = usageTracker.usageData else { return }
            let usage = StatusProvider.current == .openai ? data.codex : data.claude
            addLabel(to: menu, title: "Usage (today / 90d)", bold: true)
            addLabel(to: menu, title: "  Cost: \(Self.formatCostFull(usage.costToday)) / \(Self.formatCostFull(usage.cost90d))")
            addLabel(to: menu, title: "  Tokens: \(Self.formatTokens(usage.tokensToday)) / \(Self.formatTokens(usage.tokens90d))")
        }
    }

    private func usageBarTitle() -> String {
        guard UsageTracker.isEnabled,
              case .available = usageTracker.availability,
              let data = usageTracker.usageData else { return "" }

        let usage = StatusProvider.current == .openai ? data.codex : data.claude
        var parts: [String] = []
        if UsageTracker.showToday { parts.append(Self.formatCostCompact(usage.costToday)) }
        if UsageTracker.show90d { parts.append(Self.formatCostCompact(usage.cost90d)) }
        guard !parts.isEmpty else { return "" }
        return " " + parts.joined(separator: "/")
    }

    private static func formatCostCompact(_ cost: Double) -> String {
        switch cost {
        case ..<0.01: return "$0"
        case ..<10: return String(format: "$%.1f", cost)
        case ..<1000: return String(format: "$%.0f", cost)
        default:
            let k = cost / 1000
            return k < 10 ? String(format: "$%.1fk", k) : String(format: "$%.0fk", k)
        }
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func formatCostFull(_ cost: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: cost)) ?? String(format: "$%.2f", cost)
    }

    private static func formatTokens(_ tokens: Int) -> String {
        switch tokens {
        case ..<1_000: return "\(tokens)"
        case ..<1_000_000: return String(format: "%.0fK", Double(tokens) / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", Double(tokens) / 1_000_000)
        default: return String(format: "%.1fB", Double(tokens) / 1_000_000_000)
        }
    }

    static func dotImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let dot: CGFloat = 8
            let dotRect = NSRect(x: (rect.width - dot) / 2, y: (rect.height - dot) / 2, width: dot, height: dot)
            color.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
