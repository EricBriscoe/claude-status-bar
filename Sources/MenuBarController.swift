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
    private var summary: StatusSummary?
    private var fetchError: String?
    private var lastChecked: Date?
    private var timer: Timer?

    private static let apiURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
    private static let pageURL = URL(string: "https://status.claude.com")!
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
        statusItem.button?.toolTip = "Claude Status"
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
        Task {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let (data, _) = try await URLSession.shared.data(from: Self.apiURL)
                let response = try decoder.decode(StatusSummary.self, from: data)
                await MainActor.run {
                    self.summary = response
                    self.fetchError = nil
                }
            } catch {
                await MainActor.run {
                    self.fetchError = error.localizedDescription
                }
            }
            await MainActor.run {
                self.lastChecked = Date()
                self.updateUI()
            }
        }
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
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let summary {
            addLabel(to: menu, title: summary.status.description, bold: true)
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

        menu.addItem(.separator())

        if let lastChecked {
            addLabel(to: menu, title: "Updated \(Self.timeFormatter.string(from: lastChecked))")
        }

        addAction(to: menu, title: "Refresh", key: "r", action: #selector(handleRefresh))
        menu.addItem(.separator())
        addAction(to: menu, title: "Open Status Page", key: "o", action: #selector(handleOpenPage))

        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(handleToggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

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

    @objc private func handleRefresh() { fetch() }

    @objc private func handleOpenPage() {
        NSWorkspace.shared.open(Self.pageURL)
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

    @objc private func handleQuit() { NSApp.terminate(nil) }

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
