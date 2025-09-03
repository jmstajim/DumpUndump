import Foundation
import CryptoKit

@inline(__always)
private func col(_ s: String, _ width: Int) -> String {
    if s.count >= width { return s }
    return s + String(repeating: " ", count: width - s.count)
}

@inline(__always)
private func col(_ n: Int, _ width: Int) -> String {
    col(String(n), width)
}

@inline(__always)
private func countLines(_ data: Data) -> Int {
    if data.isEmpty { return 1 }
    var c = 1
    data.forEach { if $0 == 10 { c += 1 } }
    return c
}

enum Dump {
    static func dump(root: URL, options: DumpOptions) throws -> DumpResult {
        let filter = FileFilter(root: root, includeGlobs: options.includeGlobs, excludeGlobs: options.excludeGlobs, excludeDirs: options.excludeDirs, skipLargeFiles: options.skipLargeFiles, maxSizeMB: options.maxSizeMB)
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            throw NSError(domain: "Dump", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to list files in \(root.path)"])
        }
        var files: [URL] = []
        for case let url as URL in en {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { continue }
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if filter.shouldSkipDirectory(url) {
                    (en as AnyObject).skipDescendants?()
                    continue
                }
            }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            if !filter.basicFilePass(url: url, size: size) { continue }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), filter.isText(data) else { continue }
            files.append(url)
        }
        files.sort { $0.path.compare($1.path, options: [.caseInsensitive, .numeric]) == .orderedAscending }
        let dateStr = isoNow()

        var pairSections: [(Int, String)] = []
        var pairToc: [(Int, String)] = []
        var pairManifest: [(Int, [String: Any])] = []
        let headerToc = "\(col("INDEX", 7))  \(col("BYTES", 8))  \(col("LINES", 8))  \(col("EXT", 8))  RELATIVE_PATH"
        let hasher = SHA256Incremental()

        DispatchQueue.concurrentPerform(iterations: files.count) { idx in
            let index = idx + 1
            let url = files[idx]
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let ext = url.pathExtension
            let data = (try? Data(contentsOf: url, options: .mappedIfSafe)) ?? Data()
            let linesCount = countLines(data)
            let fenceLang = codeFenceLang(for: ext)
            let hash = sha256Hex(data)
            let utf8Text = String(data: data, encoding: .utf8)
            let enc = "utf8"
            let bodyString = utf8Text ?? ""
            let contentBytes = bodyString.utf8.count
            let section = """

            <<<FILE #\(String(format: "%04d", index))>>>
            PATH: \(rel)
            EXT: \(ext.isEmpty ? "-" : ext)
            BYTES: \(data.count)
            LINES: \(linesCount)
            HASH: \(hash)
            ENC: \(enc)
            CONTENT_BYTES: \(contentBytes)
            ```\(fenceLang)
            \(bodyString)
            ```
            <<<END FILE #\(String(format: "%04d", index))>>>
            """
            let extCol = ext.isEmpty ? "-" : ext
            let tocLine = "\(col(index, 7))  \(col(data.count, 8))  \(col(linesCount, 8))  \(col(extCol, 8))  \(rel)"
            let manifestEntry: [String: Any] = [
                "index": index,
                "path": rel,
                "ext": ext,
                "bytes": data.count,
                "lines": linesCount,
                "lang": fenceLang,
                "enc": enc,
                "hash": hash,
                "content_bytes": contentBytes
            ]
            synchronizedAppend(idx: index, section: section, toc: tocLine, manifest: manifestEntry, pairSections: &pairSections, pairToc: &pairToc, pairManifest: &pairManifest)
            hasher.update(hexString: hash)
        }

        pairSections.sort { $0.0 < $1.0 }
        pairToc.sort { $0.0 < $1.0 }
        pairManifest.sort { $0.0 < $1.0 }
        let sections = pairSections.map { $0.1 }
        let tocLines = [headerToc] + pairToc.map { $0.1 }
        let manifestArray = pairManifest.map { $0.1 }
        let manifestData = try JSONSerialization.data(withJSONObject: ["files": manifestArray], options: [])
        let manifestJSON = String(data: manifestData, encoding: .utf8) ?? "{}"
        let dumpHash = hasher.finalHex()

        var out = "# \(root.lastPathComponent) FOLDER DUMP\n"
        out += "Generated: \(dateStr)\n"
        out += "FORMAT: v3\n"
        out += "FILES: \(files.count)\n"
        out += "EOL: lf\n"
        out += "ENC_DEFAULT: utf8\n"
        out += "NFC: true\n"
        out += "DUMP_SHA256: \(dumpHash)\n"
        out += "---BEGIN MANIFEST---\n"
        out += manifestJSON
        out += "\n---END MANIFEST---\n"
        out += "---BEGIN TOC---\n"
        out += tocLines.joined(separator: "\n")
        out += "\n---END TOC---\n"
        out += sections.joined()
        return DumpResult(text: out, filesCount: files.count)
    }
}

final class SHA256Incremental {
    private var ctx = CryptoKit.SHA256()
    func update(hexString: String) {
        if let d = hexString.data(using: .utf8) {
            ctx.update(data: d)
        }
    }
    func finalHex() -> String {
        let digest = ctx.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private let appendLock = NSLock()

private func synchronizedAppend(idx: Int, section: String, toc: String, manifest: [String: Any], pairSections: inout [(Int,String)], pairToc: inout [(Int,String)], pairManifest: inout [(Int,[String:Any])]) {
    appendLock.lock()
    pairSections.append((idx, section))
    pairToc.append((idx, toc))
    pairManifest.append((idx, manifest))
    appendLock.unlock()
}

func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

func splitList(_ s: String) -> [String] {
    s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
}

func isoNow() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: Date())
}

func codeFenceLang(for ext: String) -> String {
    switch ext.lowercased() {
    case "swift": return "swift"
    case "m", "mm": return "objectivec"
    case "h": return "c"
    case "c": return "c"
    case "cpp","cc","cxx","hpp","hh","hxx": return "cpp"
    case "kt": return "kotlin"
    case "java": return "java"
    case "cs": return "csharp"
    case "py": return "python"
    case "rb": return "ruby"
    case "js","mjs","cjs": return "javascript"
    case "ts","tsx": return "typescript"
    case "html","htm": return "html"
    case "css","scss","sass","less": return "css"
    case "json": return "json"
    case "yml","yaml": return "yaml"
    case "xml","plist","xib","storyboard": return "xml"
    case "md","markdown": return "md"
    case "sh","bash","zsh": return "bash"
    case "sql": return "sql"
    case "metal": return "metal"
    default: return ""
    }
}

