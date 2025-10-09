import Foundation

struct FileFilter {
    private let include: [NSRegularExpression]
    private let excludeName: [NSRegularExpression]
    private let excludePath: [NSRegularExpression]
    private let excludeDirs: Set<String>
    private let binaryExts: Set<String>
    private let maxBytes: Int
    private let skipLarge: Bool
    private let rootPrefix: String

    init(root: URL, includeGlobs: String, excludeGlobs: String, excludeDirs: String, skipLargeFiles: Bool, maxSizeMB: Int, binaryExts: Set<String>? = nil) {
        self.include = FileFilter.compile(globs: includeGlobs)
        let split = FileFilter.compileSplit(globs: excludeGlobs)
        self.excludeName = split.names
        self.excludePath = split.paths
        self.excludeDirs = Set(excludeDirs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
        let defaults: Set<String> = ["png","jpg","jpeg","gif","webp","pdf","zip","rar","7z","dmg","ico","icns","ttf","otf","mp3","wav","aiff","mp4","mov","avi","m4a","m4v","heic","heif","xcassets","xcuserstate","bin","so","dylib","a","o","class","jar","war","ipa"]
        self.binaryExts = binaryExts ?? defaults
        self.skipLarge = skipLargeFiles
        self.maxBytes = skipLargeFiles ? maxSizeMB * 1024 * 1024 : Int.max
        let base = root.path
        self.rootPrefix = base.hasSuffix("/") ? base : base + "/"
    }

    static func compile(globs: String) -> [NSRegularExpression] {
        globs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.compactMap { globToRegex($0) }
    }

    static func compileSplit(globs: String) -> (names: [NSRegularExpression], paths: [NSRegularExpression]) {
        var names: [NSRegularExpression] = []
        var paths: [NSRegularExpression] = []
        for raw in globs.split(separator: ",") {
            let p = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty { continue }
            if let rx = globToRegex(p) {
                if p.contains("/") || p.contains("\\") {
                    paths.append(rx)
                } else {
                    names.append(rx)
                }
            }
        }
        return (names, paths)
    }

    private static func globToRegex(_ pattern: String) -> NSRegularExpression? {
        var s = "^"
        for ch in pattern {
            if ch == "*" { s += ".*" }
            else if ch == "?" { s += "." }
            else if ".^$+()[]{}|\\".contains(ch) { s += "\\\(ch)" }
            else { s += String(ch) }
        }
        s += "$"
        return try? NSRegularExpression(pattern: s, options: [.caseInsensitive])
    }

    func shouldSkipDirectory(_ url: URL) -> Bool {
        excludeDirs.contains(url.lastPathComponent.lowercased())
    }

    func basicFilePass(url: URL, size: Int?) -> Bool {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        if binaryExts.contains(ext) { return false }
        if !include.isEmpty && !include.contains(where: { $0.firstMatch(in: name, options: [], range: NSRange(location: 0, length: name.utf16.count)) != nil }) { return false }
        if !excludeName.isEmpty && excludeName.contains(where: { $0.firstMatch(in: name, options: [], range: NSRange(location: 0, length: name.utf16.count)) != nil }) { return false }
        let rel = relativePath(url)
        if !excludePath.isEmpty && excludePath.contains(where: { $0.firstMatch(in: rel, options: [], range: NSRange(location: 0, length: rel.utf16.count)) != nil }) { return false }
        if skipLarge, let size = size, size > maxBytes { return false }
        return true
    }

    private func relativePath(_ url: URL) -> String {
        let p = url.path
        if p.hasPrefix(rootPrefix) {
            let start = rootPrefix.count
            if p.count > start {
                return String(p.dropFirst(start))
            } else {
                return ""
            }
        }
        return url.lastPathComponent
    }

    func isText(_ data: Data) -> Bool {
        if data.isEmpty { return true }
        let sample = data.prefix(4096)
        if sample.contains(0) { return false }
        var control = 0
        var total = 0
        for b in sample {
            total += 1
            if b < 32 && b != 9 && b != 10 && b != 13 { control += 1 }
        }
        return Double(control) / Double(max(total,1)) < 0.30
    }
}
