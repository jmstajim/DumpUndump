import Foundation

struct FileFilter {
    private let binaryExts: Set<String>
    private let maxBytes: Int
    private let skipLarge: Bool
    private let rootPrefix: String

    private let includeSelections: Set<String>
    private let excludeSelections: Set<String>

    init(root: URL, skipLargeFiles: Bool, maxSizeMB: Int, binaryExts: Set<String>? = nil, selectedPaths: [String]? = nil) {
        let defaults: Set<String> = ["png","jpg","jpeg","gif","webp","pdf","zip","rar","7z","dmg","ico","icns","ttf","otf","mp3","wav","aiff","mp4","mov","avi","m4a","m4v","heic","heif","xcassets","xcuserstate","bin","so","dylib","a","o","class","jar","war","ipa"]
        self.binaryExts = binaryExts ?? defaults
        self.skipLarge = skipLargeFiles
        self.maxBytes = skipLargeFiles ? maxSizeMB * 1024 * 1024 : Int.max
        let base = root.path
        self.rootPrefix = base.hasSuffix("/") ? base : base + "/"

        let sel = Set(selectedPaths ?? [])
        var inc = Set<String>()
        var exc = Set<String>()
        for p in sel {
            if p.hasPrefix("!") {
                let trimmed = String(p.dropFirst())
                if !trimmed.isEmpty { exc.insert(trimmed) }
            } else {
                if !p.isEmpty { inc.insert(p) }
            }
        }
        self.includeSelections = inc
        self.excludeSelections = exc
    }

    func basicFilePass(url: URL, size: Int?) -> Bool {
        let ext = url.pathExtension.lowercased()
        if binaryExts.contains(ext) { return false }
        let rel = relativePath(url)

        if includeSelections.isEmpty { return false }

        if isUnderExcludeSelection(rel) { return false }

        if !isUnderIncludeSelection(rel) { return false }

        if skipLarge, let size = size, size > maxBytes { return false }
        return true
    }

    private func isUnderIncludeSelection(_ rel: String) -> Bool {
        for sel in includeSelections {
            if rel == sel { return true }
            let s = sel.hasSuffix("/") ? sel : sel + "/"
            if rel.hasPrefix(s) { return true }
        }
        return false
    }

    private func isUnderExcludeSelection(_ rel: String) -> Bool {
        for ex in excludeSelections {
            if rel == ex { return true }
            let s = ex.hasSuffix("/") ? ex : ex + "/"
            if rel.hasPrefix(s) { return true }
        }
        return false
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

