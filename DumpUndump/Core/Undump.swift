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

            switch sec.bodyKind {
            case .fullText:
                applyFullTextSection(sec, path: path, url: url, dryRun: dryRun, makeBackups: makeBackups, fm: fm, report: &report)

            case .unifiedDiff:
                applyUnifiedDiffSection(sec, path: path, url: url, dryRun: dryRun, makeBackups: makeBackups, fm: fm, report: &report)
            }
        }

        return report
    }

    enum UndumpError: Error {
        case encoding
    }

    enum SectionBodyKind: Equatable {
        case fullText
        case unifiedDiff
    }

    struct Section: Equatable {
        let path: String
        let body: String
        let isDeletion: Bool
        let fenceLanguage: String?
        let bodyKind: SectionBodyKind
    }

    private static func applyFullTextSection(
        _ sec: Section,
        path: String,
        url: URL,
        dryRun: Bool,
        makeBackups: Bool,
        fm: FileManager,
        report: inout UndumpReport
    ) {
        let exists = fm.fileExists(atPath: url.path)
        let normalized = normalizeFileBody(sec.body)

        if sec.isDeletion {
            if !exists {
                report.skipped.append(path)
                return
            }
            if dryRun {
                report.updated.append(path)
                return
            }

            do {
                if makeBackups {
                    _ = try backupExistingFile(at: url)
                }
                try fm.removeItem(at: url)
                report.updated.append(path)
            } catch {
                report.failed.append(path)
                report.issues.append(UndumpIssue(path: path, message: issueMessage(for: error)))
            }
            return
        }

        if !dryRun {
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            } catch {
                report.failed.append(path)
                report.issues.append(UndumpIssue(path: path, message: issueMessage(for: error)))
                return
            }
        }

        if exists, let existing = try? String(contentsOf: url, encoding: .utf8) {
            if normalizeFileBody(existing) == normalized {
                report.skipped.append(path)
                return
            }

            if dryRun {
                report.updated.append(path)
                return
            }

            do {
                if makeBackups {
                    _ = try backupExistingFile(at: url)
                }
                guard let data = normalized.data(using: .utf8) else { throw UndumpError.encoding }
                try data.write(to: url, options: .atomic)
                report.updated.append(path)
            } catch {
                report.failed.append(path)
                report.issues.append(UndumpIssue(path: path, message: issueMessage(for: error)))
            }
        } else {
            if dryRun {
                report.created.append(path)
                return
            }

            do {
                guard let data = normalized.data(using: .utf8) else { throw UndumpError.encoding }
                try data.write(to: url, options: .atomic)
                report.created.append(path)
            } catch {
                report.failed.append(path)
                report.issues.append(UndumpIssue(path: path, message: issueMessage(for: error)))
            }
        }
    }

    private static func applyUnifiedDiffSection(
        _ sec: Section,
        path: String,
        url: URL,
        dryRun: Bool,
        makeBackups: Bool,
        fm: FileManager,
        report: inout UndumpReport
    ) {
        do {
            let patch = try validateUnifiedDiffSection(sec)

            let existedBefore = fm.fileExists(atPath: url.path)
            let oldText: String = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

            let applied = try UnifiedDiffApplier.apply(patch: patch, to: oldText)
            let newText = normalizeFileBody(applied)

            if normalizeFileBody(oldText) == newText {
                report.skipped.append(path)
                return
            }

            if dryRun {
                if existedBefore { report.updated.append(path) }
                else { report.created.append(path) }
                return
            }

            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                if makeBackups, existedBefore {
                    _ = try backupExistingFile(at: url)
                }
                guard let data = newText.data(using: .utf8) else { throw UndumpError.encoding }
                try data.write(to: url, options: .atomic)
                if existedBefore { report.updated.append(path) }
                else { report.created.append(path) }
            } catch {
                report.failed.append(path)
                report.issues.append(UndumpIssue(path: path, message: issueMessage(for: error)))
            }
        } catch {
            report.failed.append(path)
            report.issues.append(UndumpIssue(path: path, message: issueMessage(for: error)))
        }
    }

    private static func validateUnifiedDiffSection(_ section: Section) throws -> UnifiedDiffPatch {
        let expected = section.path.trimmingCharacters(in: .whitespacesAndNewlines)
        return try UnifiedDiffParser.parseSingleFilePatch(section.body, expectedPath: expected)
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

            let langRaw = ns.substring(with: fenceStart.range(at: 2))
            let fenceLanguage = langRaw.isEmpty ? nil : langRaw

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

            let kind: SectionBodyKind = (fenceLanguage?.lowercased() == "diff") ? .unifiedDiff : .fullText
            let isDeletion = (kind == .fullText && body.isEmpty)

            sections.append(Section(path: path, body: body, isDeletion: isDeletion, fenceLanguage: fenceLanguage, bodyKind: kind))

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

    private static func issueMessage(for error: Error) -> String {
        if let e = error as? UnifiedDiffParseError {
            switch e {
            case .empty:
                return "Unified diff is empty."
            case .multiFileNotAllowed:
                return "Unified diff must affect a single file."
            case .binaryNotSupported:
                return "Binary diffs are not supported."
            case .gitBinaryPatchNotSupported:
                return "GIT binary patch is not supported."
            case .deleteNotSupported:
                return "Delete-via-diff is not supported."
            case .missingHunks:
                return "Unified diff contains no hunks."
            case .malformedHunkHeader(let s):
                return "Malformed unified diff: \(s)"
            case .missingFileHeader:
                return "Unified diff is missing file header lines (---/+++)."
            case .pathMismatch(let expected, let got):
                return "Path mismatch: expected \(expected), got \(got)."
            }
        }

        if let e = error as? UnifiedDiffApplyError {
            switch e {
            case .contextMismatch(let expected, let actual, let lineIndex):
                return "Context mismatch at line \(lineIndex + 1): expected '\(expected)', got '\(actual)'."
            case .outOfBounds(let expectedLineIndex):
                return "Patch refers to out-of-bounds line index \(expectedLineIndex + 1)."
            }
        }

        if let e = error as? UndumpError {
            switch e {
            case .encoding:
                return "Failed to encode text as UTF-8."
            }
        }

        return (error as NSError).localizedDescription
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
