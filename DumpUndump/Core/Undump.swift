import Foundation

enum Undump {
    static func undump(text: String, toRoot root: URL, dryRun: Bool, makeBackups: Bool) throws -> UndumpReport {
        let sections = parseSections(from: text)
        var report = UndumpReport()
        let fm = FileManager.default

        for sec in sections {
            let path = sec.path.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty || path.hasPrefix("/") || path.contains("..") {
                report.skipped.append(path.isEmpty ? "<empty path>" : path)
                continue
            }
            let url = root.appendingPathComponent(path)

            let exists = fm.fileExists(atPath: url.path)
            let normalized = normalizeFileBody(sec.body)

            if sec.isDeletion {
                if !exists {
                    report.skipped.append(path)
                    continue
                }
                if dryRun {
                    report.updated.append(path)
                } else {
                    if makeBackups {
                        _ = try? backupExistingFile(at: url)
                    }
                    do {
                        try fm.removeItem(at: url)
                        report.updated.append(path)
                    } catch {
                        report.skipped.append(path)
                    }
                }
                continue
            }

            if !dryRun {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            }

            if exists, let existingData = try? Data(contentsOf: url), let existing = String(data: existingData, encoding: .utf8) {
                if existing == normalized {
                    report.skipped.append(path)
                    continue
                }
                if dryRun {
                    report.updated.append(path)
                } else {
                    if makeBackups {
                        _ = try? backupExistingFile(at: url)
                    }
                    guard let data = normalized.data(using: .utf8) else { throw UndumpError.encoding }
                    try data.write(to: url, options: .atomic)
                    report.updated.append(path)
                }
            } else {
                if dryRun {
                    report.created.append(path)
                } else {
                    guard let data = normalized.data(using: .utf8) else { throw UndumpError.encoding }
                    try data.write(to: url, options: .atomic)
                    report.created.append(path)
                }
            }
        }

        return report
    }

    enum UndumpError: Error {
        case encoding
    }

    private struct Section {
        let path: String
        let body: String
        let isDeletion: Bool
    }

    private static func parseSections(from text: String) -> [Section] {
        let ns = text as NSString

        let fileStartRx = try! NSRegularExpression(pattern: #"(?m)^<<<FILE\s+#\d+>>>$"#)
        let fileEndRx   = try! NSRegularExpression(pattern: #"(?m)^<<<END FILE\s+#\d+>>>$"#)
        let pathRx      = try! NSRegularExpression(pattern: #"(?m)^PATH:\s*(.+)$"#)
        let fenceStartRx = try! NSRegularExpression(pattern: #"(?m)^([`~]{3,})([A-Za-z0-9]*)\s*$"#)

        var sections: [Section] = []
        var searchLocation = 0
        let textLen = ns.length

        while true {
            guard let start = fileStartRx.firstMatch(in: text, options: [], range: NSRange(location: searchLocation, length: textLen - searchLocation)) else {
                break
            }
            guard let end = fileEndRx.firstMatch(in: text, options: [], range: NSRange(location: NSMaxRange(start.range), length: textLen - NSMaxRange(start.range))) else {
                break
            }

            let middleRange = NSRange(location: NSMaxRange(start.range), length: end.range.location - NSMaxRange(start.range))
            guard let pathM = pathRx.firstMatch(in: text, options: [], range: middleRange) else {
                searchLocation = NSMaxRange(end.range)
                continue
            }
            let path = ns.substring(with: pathM.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)

            let afterPathRange = NSRange(location: NSMaxRange(pathM.range), length: NSMaxRange(end.range) - NSMaxRange(pathM.range))
            guard let fenceStart = fenceStartRx.firstMatch(in: text, options: [], range: afterPathRange) else {
                searchLocation = NSMaxRange(end.range)
                continue
            }
            let marker = ns.substring(with: fenceStart.range(at: 1))

            let escapedMarker = NSRegularExpression.escapedPattern(for: marker)
            let fenceEndRx = try! NSRegularExpression(pattern: "(?m)^\(escapedMarker)\\s*$")

            let afterFenceStart = NSRange(location: NSMaxRange(fenceStart.range), length: NSMaxRange(end.range) - NSMaxRange(fenceStart.range))
            guard let fenceEnd = fenceEndRx.firstMatch(in: text, options: [], range: afterFenceStart) else {
                searchLocation = NSMaxRange(end.range)
                continue
            }

            let bodyRange = NSRange(location: NSMaxRange(fenceStart.range), length: fenceEnd.range.location - NSMaxRange(fenceStart.range))
            var body = ns.substring(with: bodyRange)

            if body.hasPrefix("\n") { body.removeFirst() }

            let isDeletion = body.isEmpty
            sections.append(Section(path: path, body: body, isDeletion: isDeletion))

            searchLocation = NSMaxRange(end.range)
        }

        return sections
    }

    private static func normalizeFileBody(_ body: String) -> String {
        var s = body.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if !s.hasSuffix("\n") { s.append("\n") }
        #if canImport(Foundation)
        s = s.precomposedStringWithCanonicalMapping
        #endif
        return s
    }

    @discardableResult
    private static func backupExistingFile(at url: URL) throws -> URL {
        let ts = isoNow().replacingOccurrences(of: ":", with: "-")
        let base = url.deletingPathExtension()
        let ext = url.pathExtension.isEmpty ? "txt" : url.pathExtension
        let backupURL = base.appendingPathExtension("bak-\(ts)").appendingPathExtension(ext)
        try FileManager.default.copyItem(at: url, to: backupURL)
        return backupURL
    }

    private static func isoNow() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: Date())
    }
}
