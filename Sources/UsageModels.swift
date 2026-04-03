import Foundation

struct CcusageResponse: Codable {
    let daily: [CcusageDailyEntry]
    let totals: CcusageTotals?
}

protocol CostBearing: Codable {
    var totalCost: Double? { get }
    var costUSD: Double? { get }
}

extension CostBearing {
    var cost: Double { totalCost ?? costUSD ?? 0 }
}

struct CcusageDailyEntry: CostBearing {
    let date: String
    let totalTokens: Int
    let totalCost: Double?
    let costUSD: Double?
}

struct CcusageTotals: CostBearing {
    let totalTokens: Int
    let totalCost: Double?
    let costUSD: Double?
}

struct UsageData {
    struct ProviderUsage {
        let costToday: Double
        let cost90d: Double
        let tokensToday: Int
        let tokens90d: Int
    }

    let claude: ProviderUsage
    let codex: ProviderUsage

    var costToday: Double { claude.costToday + codex.costToday }
    var cost90d: Double { claude.cost90d + codex.cost90d }
    var tokensToday: Int { claude.tokensToday + codex.tokensToday }
    var tokens90d: Int { claude.tokens90d + codex.tokens90d }
}
