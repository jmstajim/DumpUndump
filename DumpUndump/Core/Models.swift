import Foundation

struct DumpOptions: Codable, Equatable {
    var skipLargeFiles: Bool
    var maxSizeMB: Int
    var selectedPaths: [String]? = nil

    static let `default` = DumpOptions(
        skipLargeFiles: true,
        maxSizeMB: 5
    )
}

struct DumpResult {
    let text: String
    let filesCount: Int
}

struct UndumpReport {
    var created: [String] = []
    var updated: [String] = []
    var skipped: [String] = []

    var summary: String {
        var parts: [String] = []
        if !created.isEmpty { parts.append("Created: \(created.count)") }
        if !updated.isEmpty { parts.append("Updated: \(updated.count)") }
        if !skipped.isEmpty { parts.append("Skipped: \(skipped.count)") }
        return parts.isEmpty ? "" : parts.joined(separator: " • ")
    }
}
