import Foundation

enum Undump {
    static func undump(text: String, toRoot root: URL, dryRun: Bool, makeBackups: Bool) throws -> UndumpReport {
        let sections = parseSections(from: text)
        var report = UndumpReport()
        let fm = FileManager.default

        for sec in sections {
            // Validate path
            let path = sec.path.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty || path.hasPrefix("/") || path.contains("..") {
                report.skipped.append(path.isEmpty ? "<empty path>" : path)
                continue
            }
            let url = root.appendingPathComponent(path)

            // Compute write/delete plan
            let exists = fm.fileExists(atPath: url.path)
            let normalized = normalizeFileBody(sec.body)

            if sec.isDeletion {
                if !exists {
                    report.skipped.append(path)
                    continue
                }
                // Delete
                if dryRun {
                    report.updated.append(path) // would delete
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

            // Ensure parent directory
            if !dryRun {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            }

            // Write or skip if identical
            if exists, let existingData = try? Data(contentsOf: url), let existing = String(data: existingData, encoding: .utf8) {
                if existing == normalized {
                    report.skipped.append(path)
                    continue
                }
                if dryRun {
                    report.updated.append(path) // would update
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
                    report.created.append(path) // would create
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

    /// Parses FILE SECTION FORMAT:
    /// <<<FILE #0001>>>
    /// PATH: relative/path
    /// ```[lang] or ~~~
    /// <body>
    /// ``` or ~~~
    /// <<<END FILE #0001>>>
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

            // Find fence start after PATH
            let afterPathRange = NSRange(location: NSMaxRange(pathM.range), length: NSMaxRange(end.range) - NSMaxRange(pathM.range))
            guard let fenceStart = fenceStartRx.firstMatch(in: text, options: [], range: afterPathRange) else {
                searchLocation = NSMaxRange(end.range)
                continue
            }
            let marker = ns.substring(with: fenceStart.range(at: 1))

            // Closing fence must match marker
            let escapedMarker = NSRegularExpression.escapedPattern(for: marker)
            let fenceEndRx = try! NSRegularExpression(pattern: "(?m)^\(escapedMarker)\\s*$")

            // Search for closing fence between fenceStart and block end
            let afterFenceStart = NSRange(location: NSMaxRange(fenceStart.range), length: NSMaxRange(end.range) - NSMaxRange(fenceStart.range))
            guard let fenceEnd = fenceEndRx.firstMatch(in: text, options: [], range: afterFenceStart) else {
                searchLocation = NSMaxRange(end.range)
                continue
            }

            // Extract body
            let bodyRange = NSRange(location: NSMaxRange(fenceStart.range), length: fenceEnd.range.location - NSMaxRange(fenceStart.range))
            var body = ns.substring(with: bodyRange)

            // Remove a single leading newline (common after opening fence)
            if body.hasPrefix("\n") { body.removeFirst() }

            let isDeletion = body.isEmpty
            sections.append(Section(path: path, body: body, isDeletion: isDeletion))

            searchLocation = NSMaxRange(end.range)
        }

        return sections
    }

    /// Normalizes the body to UTF-8 text with LF line endings, NFC, and a trailing newline.
    private static func normalizeFileBody(_ body: String) -> String {
        var s = body.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if !s.hasSuffix("\n") { s.append("\n") }
        // NFC normalization
        #if canImport(Foundation)
        s = s.precomposedStringWithCanonicalMapping
        #endif
        return s
    }

    /// Creates a timestamped .bak backup of an existing file.
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


