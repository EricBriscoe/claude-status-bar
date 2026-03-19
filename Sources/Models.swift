import Foundation

extension JSONDecoder {
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

struct StatusSummary: Codable {
    let status: OverallStatus
    let components: [ServiceComponent]
    let incidents: [Incident]
}

struct OverallStatus: Codable {
    let indicator: String
    let description: String
}

struct ServiceComponent: Codable {
    let name: String
    let status: String
}

struct Incident: Codable {
    let name: String
    let status: String
    let impact: String
    let incidentUpdates: [IncidentUpdate]?
}

struct IncidentUpdate: Codable {
    let body: String
}
