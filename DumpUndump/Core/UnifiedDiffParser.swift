import Foundation

struct UnifiedDiffParser {
    /// Parses a unified diff that MUST affect a single file and MUST correspond to `expectedPath`.
    static func parseSingleFilePatch(_ text: String, expectedPath: String) throws -> UnifiedDiffPatch {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { throw UnifiedDiffParseError.empty }

        // Hard rejects:
        if raw.contains("Binary files ") && raw.contains(" differ") {
            throw UnifiedDiffParseError.binaryNotSupported
        }
        if raw.contains("GIT binary patch") {
            throw UnifiedDiffParseError.gitBinaryPatchNotSupported
        }

        // Multi-file reject (single-file only):
        // If more than one "diff --git" appears -> reject.
        let diffGitCount = raw.components(separatedBy: "\ndiff --git ").count - 1
        if diffGitCount > 1 { throw UnifiedDiffParseError.multiFileNotAllowed }

        // Parse headers:
        // We accept optional "diff --git ..." and optional "index ..."
        // We require --- and +++ lines before hunks.
        var originalPath: String? = nil
        var newPath: String? = nil
        var isNewFile = false
        var isDelete = false

        // Split lines preserving empty lines.
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var i = 0
        var sawOriginal = false
        var sawNew = false

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("--- ") {
                if sawOriginal { throw UnifiedDiffParseError.multiFileNotAllowed }
                sawOriginal = true

                let p = String(line.dropFirst(4))
                if p == "/dev/null" { isNewFile = true; originalPath = nil }
                else { originalPath = p }
            } else if line.hasPrefix("+++ ") {
                if sawNew { throw UnifiedDiffParseError.multiFileNotAllowed }
                sawNew = true

                let p = String(line.dropFirst(4))
                if p == "/dev/null" { isDelete = true; newPath = nil }
                else { newPath = p }
            } else if line.hasPrefix("@@ ") {
                break
            } else if line.hasPrefix("diff --git ") && (sawOriginal || sawNew) {
                // A second file starting without the usual header count heuristic.
                throw UnifiedDiffParseError.multiFileNotAllowed
            }

            i += 1
        }

        if isDelete { throw UnifiedDiffParseError.deleteNotSupported }
        if originalPath == nil && newPath == nil && !isNewFile {
            throw UnifiedDiffParseError.missingFileHeader
        }

        // Validate path binding if we have +++ path, otherwise fall back to --- path.
        if let pathToValidate = newPath ?? originalPath {
            let normalized = normalizeGitPath(pathToValidate)
            if normalized != expectedPath && !normalized.hasSuffix("/" + expectedPath) {
                throw UnifiedDiffParseError.pathMismatch(expected: expectedPath, got: normalized)
            }
        }

        // Parse hunks
        var hunks: [UnifiedDiffHunk] = []
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("@@ ") {
                let header = line
                guard let h = try parseHunkHeader(header) else {
                    throw UnifiedDiffParseError.malformedHunkHeader(header)
                }
                i += 1

                var hunkLines: [UnifiedDiffHunkLine] = []
                while i < lines.count {
                    let l = lines[i]
                    if l.hasPrefix("@@ ") { break }
                    if l.hasPrefix("diff --git ") { throw UnifiedDiffParseError.multiFileNotAllowed }
                    if l.hasPrefix("--- ") && (sawOriginal || sawNew) { throw UnifiedDiffParseError.multiFileNotAllowed }
                    if l.hasPrefix("+++ ") && (sawOriginal || sawNew) { throw UnifiedDiffParseError.multiFileNotAllowed }

                    if l.hasPrefix("\\ No newline at end of file") {
                        i += 1
                        continue
                    }

                    if l.isEmpty {
                        // Truly empty line here is treated as an empty context line.
                        hunkLines.append(.context(""))
                        i += 1
                        continue
                    }

                    let prefix = l.first!
                    let payload = String(l.dropFirst())
                    switch prefix {
                    case " ":
                        hunkLines.append(.context(payload))
                    case "+":
                        hunkLines.append(.add(payload))
                    case "-":
                        hunkLines.append(.remove(payload))
                    default:
                        // Non-standard line inside hunk -> strict reject.
                        throw UnifiedDiffParseError.malformedHunkHeader("Unexpected hunk line: \(l)")
                    }
                    i += 1
                }

                hunks.append(UnifiedDiffHunk(
                    oldStart: h.oldStart, oldCount: h.oldCount,
                    newStart: h.newStart, newCount: h.newCount,
                    lines: hunkLines
                ))
                continue
            }
            i += 1
        }

        if hunks.isEmpty { throw UnifiedDiffParseError.missingHunks }

        return UnifiedDiffPatch(
            expectedPath: expectedPath,
            originalPath: originalPath,
            newPath: newPath,
            isNewFile: isNewFile,
            isDelete: isDelete,
            hunks: hunks
        )
    }

    private static func normalizeGitPath(_ p: String) -> String {
        if p.hasPrefix("a/") { return String(p.dropFirst(2)) }
        if p.hasPrefix("b/") { return String(p.dropFirst(2)) }
        return p
    }

    private struct ParsedHunkHeader {
        let oldStart: Int
        let oldCount: Int
        let newStart: Int
        let newCount: Int
    }

    /// Parses headers like: @@ -1,3 +1,4 @@  (counts may be omitted)
    private static func parseHunkHeader(_ line: String) throws -> ParsedHunkHeader? {
        // Minimal strict parser without regex dependencies:
        // "@@ -<oldStart>[,<oldCount>] +<newStart>[,<newCount>] @@"
        guard line.hasPrefix("@@ ") else { return nil }
        guard let closeRange = line.range(
            of: " @@",
            options: [],
            range: line.index(line.startIndex, offsetBy: 3)..<line.endIndex
        ) else {
            return nil
        }
        let inner = String(line[line.index(line.startIndex, offsetBy: 3)..<closeRange.lowerBound])
        // inner expected like: "-1,3 +1,4" or "-1 +1"
        let parts = inner.split(separator: " ")
        if parts.count < 2 { return nil }

        func parseRangeToken(_ tok: Substring, expectedPrefix: Character) -> (Int, Int)? {
            guard tok.first == expectedPrefix else { return nil }
            let rest = tok.dropFirst()
            let comps = rest.split(separator: ",", omittingEmptySubsequences: false)
            guard let start = Int(comps[0]) else { return nil }
            let count: Int
            if comps.count >= 2, let c = Int(comps[1]) { count = c } else { count = 1 }
            return (start, count)
        }

        guard let (oldStart, oldCount) = parseRangeToken(parts[0], expectedPrefix: "-") else { return nil }
        guard let (newStart, newCount) = parseRangeToken(parts[1], expectedPrefix: "+") else { return nil }
        return ParsedHunkHeader(oldStart: oldStart, oldCount: oldCount, newStart: newStart, newCount: newCount)
    }
}
