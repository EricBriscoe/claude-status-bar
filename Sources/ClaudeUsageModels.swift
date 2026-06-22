import Foundation

struct ClaudeUsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let sevenDayCowork: UsageBucket?
    let extraUsage: ClaudeExtraUsage?
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String
}

struct ClaudeExtraUsage: Codable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?
}
