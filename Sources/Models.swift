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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(OverallStatus.self, forKey: .status)
        components = try container.decode([ServiceComponent].self, forKey: .components)
        incidents = try container.decodeIfPresent([Incident].self, forKey: .incidents) ?? []
    }
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
