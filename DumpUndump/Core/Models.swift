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

struct UndumpIssue: Equatable {
    let path: String
    let message: String
}

struct UndumpReport: Equatable {
    var created: [String] = []
    var updated: [String] = []
    var skipped: [String] = []
    var failed: [String] = []
    var issues: [UndumpIssue] = []

    var summary: String {
        var parts: [String] = []
        if !created.isEmpty { parts.append("Created: \(created.count)") }
        if !updated.isEmpty { parts.append("Updated: \(updated.count)") }
        if !skipped.isEmpty { parts.append("Skipped: \(skipped.count)") }
        if !failed.isEmpty { parts.append("Failed: \(failed.count)") }
        return parts.isEmpty ? "" : parts.joined(separator: " • ")
    }
}
