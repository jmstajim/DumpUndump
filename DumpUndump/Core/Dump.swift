import Foundation

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
        let headerToc = "\(col("INDEX", 7))  \(col("BYTES", 8))  \(col("LINES", 8))  \(col("EXT", 8))  RELATIVE_PATH"

        DispatchQueue.concurrentPerform(iterations: files.count) { idx in
            let index = idx + 1
            let url = files[idx]
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let data = (try? Data(contentsOf: url, options: .mappedIfSafe)) ?? Data()
            let linesCount = countLines(data)
            let utf8Text = String(data: data, encoding: .utf8)
            let bodyString = utf8Text ?? ""
            let section = """

            <<<FILE #\(index)>>>
            PATH: \(rel)
            ```
            \(bodyString)
            ```
            <<<END FILE #\(index)>>>
            """
            let tocLine = "\(col(index, 7))  \(col(data.count, 8))  \(col(linesCount, 8))  \(rel)"
            synchronizedAppend(idx: index, section: section, toc: tocLine, pairSections: &pairSections, pairToc: &pairToc)
        }

        pairSections.sort { $0.0 < $1.0 }
        pairToc.sort { $0.0 < $1.0 }
        let sections = pairSections.map { $0.1 }
        let tocLines = [headerToc] + pairToc.map { $0.1 }

        var out = "# \(root.lastPathComponent) FOLDER DUMP\n"
        out += "Generated: \(dateStr)\n"
        out += "FILES: \(files.count)\n"
        out += "EOL: lf\n"
        out += "ENC_DEFAULT: utf8\n"
        out += "NFC: true\n"
        out += "---BEGIN TOC---\n"
        out += tocLines.joined(separator: "\n")
        out += "\n---END TOC---\n"
        out += sections.joined()
        return DumpResult(text: out, filesCount: files.count)
    }
}

private let appendLock = NSLock()

private func synchronizedAppend(idx: Int, section: String, toc: String, pairSections: inout [(Int,String)], pairToc: inout [(Int,String)]) {
    appendLock.lock()
    pairSections.append((idx, section))
    pairToc.append((idx, toc))
    appendLock.unlock()
}

func isoNow() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: Date())
}
