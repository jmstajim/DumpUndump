import AppKit

final class SyntaxHighlighter {
    private struct Rule {
        let regex: NSRegularExpression
        let attrs: [NSAttributedString.Key: Any]
    }

    private var rules: [Rule] = []

    init() {
        appendRules(name: "header_line", color: .lightGray)
        appendRules(name: "generated_line", color: .lightGray)
        appendRules(name: "file_markers", color: .systemRed)
        appendRules(name: "path_line", color: .linkColor)
        appendRules(name: "info_line", color: .darkGray)
        appendRules(name: "fence_line", color: .secondaryLabelColor)
    }

    func highlight(storage: NSTextStorage, baseFont: NSFont) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([.font: baseFont, .foregroundColor: NSColor.labelColor], range: full)
        let text = storage.string as NSString
        for rule in rules {
            rule.regex.enumerateMatches(in: text as String, options: [], range: full) { result, _, _ in
                if let r = result?.range {
                    storage.addAttributes(rule.attrs, range: r)
                }
            }
        }
        storage.endEditing()
    }

    private func appendRules(name: String, color: NSColor) {
        let url = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "regex") ?? Bundle.main.url(forResource: name, withExtension: "txt")
        guard let url else { return }
        guard let data = try? Data(contentsOf: url), let raw = String(data: data, encoding: .utf8) else { return }
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
        for pattern in lines {
            if let rx = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                rules.append(Rule(regex: rx, attrs: attrs))
            }
        }
    }
}
