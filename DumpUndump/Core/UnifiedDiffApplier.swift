import Foundation

enum UnifiedDiffApplyError: Error, Equatable {
    case contextMismatch(expected: String, actual: String, lineIndex: Int)
    case outOfBounds(expectedLineIndex: Int)
}

struct UnifiedDiffApplier {
    /// Applies a parsed unified diff patch to `originalText` and returns the new text.
    /// MVP: strict matching (no fuzzy search).
    static func apply(patch: UnifiedDiffPatch, to originalText: String) throws -> String {
        let normalizedOriginal = normalizeEOL(originalText)
        var fileLines = splitPreservingTrailingEmpty(normalizedOriginal)

        for h in patch.hunks {
            var cursor = max(0, h.oldStart - 1)

            // Safety: cursor may point past end in new-file cases; allow only if file is empty and oldStart == 0/1
            if cursor > fileLines.count {
                throw UnifiedDiffApplyError.outOfBounds(expectedLineIndex: cursor)
            }

            for hl in h.lines {
                switch hl {
                case .context(let s):
                    guard cursor < fileLines.count else {
                        throw UnifiedDiffApplyError.outOfBounds(expectedLineIndex: cursor)
                    }
                    if fileLines[cursor] != s {
                        throw UnifiedDiffApplyError.contextMismatch(expected: s, actual: fileLines[cursor], lineIndex: cursor)
                    }
                    cursor += 1

                case .remove(let s):
                    guard cursor < fileLines.count else {
                        throw UnifiedDiffApplyError.outOfBounds(expectedLineIndex: cursor)
                    }
                    if fileLines[cursor] != s {
                        throw UnifiedDiffApplyError.contextMismatch(expected: s, actual: fileLines[cursor], lineIndex: cursor)
                    }
                    fileLines.remove(at: cursor)
                    // cursor stays

                case .add(let s):
                    if cursor > fileLines.count {
                        throw UnifiedDiffApplyError.outOfBounds(expectedLineIndex: cursor)
                    }
                    fileLines.insert(s, at: cursor)
                    cursor += 1
                }
            }
        }

        // Join with LF and ensure trailing newline
        let joined = fileLines.joined(separator: "\n")
        return ensureTrailingNewline(joined)
    }

    private static func normalizeEOL(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    private static func ensureTrailingNewline(_ s: String) -> String {
        s.hasSuffix("\n") ? s : (s + "\n")
    }

    /// Splits by "\n". Keeps the final empty line if the string ends with "\n" by returning last element "".
    /// This matches typical unified diff expectations.
    private static func splitPreservingTrailingEmpty(_ s: String) -> [String] {
        // Using omittingEmptySubsequences: false preserves trailing empty components.
        return s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
