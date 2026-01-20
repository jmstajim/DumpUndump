import Foundation

struct UnifiedDiffPatch: Equatable {
    let expectedPath: String // PATH: from section
    let originalPath: String? // from --- a/...
    let newPath: String?      // from +++ b/...
    let isNewFile: Bool       // --- /dev/null
    let isDelete: Bool        // +++ /dev/null (MVP: reject)
    let hunks: [UnifiedDiffHunk]
}

struct UnifiedDiffHunk: Equatable {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [UnifiedDiffHunkLine]
}

enum UnifiedDiffHunkLine: Equatable {
    case context(String) // leading ' '
    case add(String)     // leading '+'
    case remove(String)  // leading '-'
}

enum UnifiedDiffParseError: Error, Equatable {
    case empty
    case multiFileNotAllowed
    case binaryNotSupported
    case gitBinaryPatchNotSupported
    case deleteNotSupported
    case missingHunks
    case malformedHunkHeader(String)
    case missingFileHeader
    case pathMismatch(expected: String, got: String)
}
