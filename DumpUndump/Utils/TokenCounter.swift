import Foundation

enum TokenCounter {
    static func estimateTokens(in text: String) -> Int {
        if text.isEmpty { return 0 }

        var count = 0
        var buffer = String()
        var i = text.startIndex

        @inline(__always)
        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            count += 1
            count += extraPieces(for: buffer)
            buffer.removeAll(keepingCapacity: true)
        }

        while i < text.endIndex {
            let ch = text[i]

            if isWhitespace(ch) {
                flushBuffer()
                i = text.index(after: i)
                continue
            }

            if isURLStart(text, at: i) {
                flushBuffer()
                let (tok, j) = consumeURL(text, from: i)
                count += tok
                i = j
                continue
            }

            if isEmailStart(text, at: i) {
                flushBuffer()
                let (tok, j) = consumeEmail(text, from: i)
                count += tok
                i = j
                continue
            }

            if Self.isEmojiGrapheme(ch) {
                flushBuffer()
                count += emojiTokenCost(ch)
                i = text.index(after: i)
                continue
            }
            if isCJK(ch) {
                flushBuffer()
                count += 1
                i = text.index(after: i)
                continue
            }

            let prev = i > text.startIndex ? text[text.index(before: i)] : nil
            let next = text.index(after: i) < text.endIndex ? text[text.index(after: i)] : nil
            if isWordlike(ch, prev: prev, next: next) {
                buffer.append(ch)
                i = text.index(after: i)
                continue
            }

            flushBuffer()
            count += 1
            i = text.index(after: i)
        }

        flushBuffer()
        return count
    }

    @inline(__always)
    private static func isURLStart(_ s: String, at i: String.Index) -> Bool {
        let sub = s[i...]
        return sub.hasPrefix("http://") || sub.hasPrefix("https://") || sub.hasPrefix("www.")
    }

    @inline(__always)
    private static func consumeURL(_ s: String, from i: String.Index) -> (Int, String.Index) {
        var j = i
        while j < s.endIndex, !isWhitespace(s[j]) { j = s.index(after: j) }
        let url = s[i..<j]

        var dots = 0, slashes = 0, q = 0, amp = 0, eq = 0, hash = 0, otherP = 0
        var alnumRuns = 0, inRun = false

        for ch in url {
            if isASCIIAlphaNum(ch) {
                if !inRun { alnumRuns += 1; inRun = true }
            } else {
                inRun = false
                switch ch {
                case ".": dots += 1
                case "/": slashes += 1
                case "?": q += 1
                case "&": amp += 1
                case "=": eq += 1
                case "#": hash += 1
                default: otherP += 1
                }
            }
        }

        let structural = dots + slashes + q + amp + eq + hash + otherP
        let tokens = 2 + structural + (alnumRuns + 1) / 2
        return (max(3, tokens), j)
    }

    @inline(__always)
    private static func isEmailStart(_ s: String, at i: String.Index) -> Bool {
        var j = i, steps = 0
        while j < s.endIndex, steps < 64, !isWhitespace(s[j]) {
            if s[j] == "@" { return true }
            j = s.index(after: j); steps += 1
        }
        return false
    }
    
    @inline(__always)
    private static func isEmojiGrapheme(_ c: Character) -> Bool {
        for s in c.unicodeScalars {
            if s.properties.isEmoji { return true }
            if s.properties.isEmojiPresentation { return true }
        }
        return false
    }

    @inline(__always)
    private static func consumeEmail(_ s: String, from i: String.Index) -> (Int, String.Index) {
        var j = i
        while j < s.endIndex, !isWhitespace(s[j]) { j = s.index(after: j) }
        let email = s[i..<j]
        guard let at = email.firstIndex(of: "@") else { return (1, j) }

        let local = email[..<at]
        let domain = email[email.index(after: at)..<email.endIndex]

        var localRuns = 0, inRun = false, plusTags = 0
        for ch in local {
            if isASCIIAlphaNum(ch) {
                if !inRun { localRuns += 1; inRun = true }
            } else {
                inRun = false
                if ch == "+" { plusTags += 1 }
            }
        }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: true).count
        let tokens = 2 + max(1, localRuns) + max(1, labels) + plusTags
        return (tokens, j)
    }

    @inline(__always)
    private static func emojiTokenCost(_ c: Character) -> Int {
        var extras = 0
        var regionalIndicators = 0
        for s in c.unicodeScalars {
            let v = Int(s.value)
            if v == 0x200D { extras += 1 }
            if v == 0xFE0F { extras += 1 }
            if (0x1F3FB...0x1F3FF).contains(v) { extras += 1 }
            if v == 0x20E3 { extras += 1 }
            if (0x1F1E6...0x1F1FF).contains(v) { regionalIndicators += 1 }
        }
        if regionalIndicators >= 2 { extras += 1 }
        return 1 + extras
    }

    @inline(__always)
    private static func isCJK(_ c: Character) -> Bool {
        for s in c.unicodeScalars {
            let v = Int(s.value)
            switch v {
            case 0x3000...0x303F, 0x3040...0x30FF, 0x31F0...0x31FF,
                 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F:
                return true
            default: break
            }
        }
        return false
    }

    @inline(__always)
    private static func isWhitespace(_ c: Character) -> Bool {
        for s in c.unicodeScalars {
            if s == "\u{200D}" { continue }
            if CharacterSet.whitespacesAndNewlines.contains(s) { return true }
            let v = Int(s.value)
            switch v {
            case 0x00A0, 0x1680, 0x202F, 0x205F, 0x3000, 0x2000...0x200A, 0x200B:
                return true
            default: break
            }
        }
        return false
    }

    @inline(__always)
    private static func isASCIIAlphaNum(_ c: Character) -> Bool {
        for s in c.unicodeScalars {
            let v = Int(s.value)
            if v < 128 && ((48...57).contains(v) || (65...90).contains(v) || (97...122).contains(v)) {
                return true
            }
        }
        return false
    }

    @inline(__always)
    private static func isAlphaNum(_ c: Character) -> Bool {
        for s in c.unicodeScalars {
            if CharacterSet.letters.contains(s) || CharacterSet.decimalDigits.contains(s) { return true }
        }
        return false
    }

    @inline(__always)
    private static func isAlphaNumOrMark(_ c: Character) -> Bool {
        for s in c.unicodeScalars {
            if CharacterSet.letters.contains(s)
                || CharacterSet.decimalDigits.contains(s)
                || CharacterSet.nonBaseCharacters.contains(s) { return true }
        }
        return false
    }

    @inline(__always)
    private static func isWordlike(_ c: Character, prev: Character?, next: Character?) -> Bool {
        if isAlphaNumOrMark(c) { return true }

        if c == "'" || c == "’" {
            if let p = prev, let n = next, isAlphaNum(p) && isAlphaNum(n) { return true }
        }
        if c == "_" || c == "-" {
            if let p = prev, let n = next,
               (isAlphaNum(p) || p == "_" || p == "-"),
               (isAlphaNum(n) || n == "_" || n == "-") { return true }
        }
        return false
    }

    @inline(__always)
    private static func extraPieces(for token: String) -> Int {
        var asciiCoreLen = 0
        var uppercaseCount = 0
        for s in token.unicodeScalars {
            let v = Int(s.value)
            let isUpper = (65...90).contains(v)
            let isLower = (97...122).contains(v)
            let isDigit = (48...57).contains(v)
            if isUpper { uppercaseCount += 1 }
            if v < 128 && (isUpper || isLower || isDigit) { asciiCoreLen += 1 }
        }

        let threshold = 8
        let chunk = 9
        var extras = 0
        if asciiCoreLen > threshold {
            extras += (asciiCoreLen - threshold + (chunk - 1)) / chunk
        }

        if uppercaseCount > 1 {
            extras += (uppercaseCount - 1) / 3
        }
        return extras
    }
}
