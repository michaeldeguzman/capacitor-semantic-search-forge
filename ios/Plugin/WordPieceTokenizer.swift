import Foundation

/// BERT uncased WordPiece tokenizer, matching Hugging Face's fast
/// BertTokenizer for all-MiniLM-L6-v2: clean text, space out CJK characters,
/// strip accents, lowercase, split on whitespace and punctuation, then greedy
/// longest-match WordPiece with "##" continuations and [UNK] fallback.
final class WordPieceTokenizer {
    static let maxCharsPerWord = 100

    private let vocab: [String: Int]
    let clsId: Int
    let sepId: Int
    let unkId: Int

    init?(vocabURL: URL) {
        guard let text = try? String(contentsOf: vocabURL, encoding: .utf8) else { return nil }
        var vocab: [String: Int] = [:]
        for (i, token) in text.components(separatedBy: "\n").enumerated() where !token.isEmpty {
            vocab[token] = i
        }
        guard let cls = vocab["[CLS]"], let sep = vocab["[SEP]"], let unk = vocab["[UNK]"] else { return nil }
        self.vocab = vocab
        clsId = cls; sepId = sep; unkId = unk
    }

    /// [CLS] + word pieces (truncated) + [SEP], at most maxLength ids.
    func encode(_ text: String, maxLength: Int) -> [Int] {
        [clsId] + tokenize(text).prefix(max(0, maxLength - 2)) + [sepId]
    }

    func tokenize(_ text: String) -> [Int] {
        basicTokens(text).flatMap(wordPieces)
    }

    // MARK: Basic tokenisation

    private func basicTokens(_ text: String) -> [String] {
        var cleaned = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            if s.value == 0 || s.value == 0xFFFD || Self.isControl(s) { continue }
            if Self.isWhitespace(s) {
                cleaned.append(" ")
            } else if Self.isCJK(s) {
                cleaned.append(" "); cleaned.append(s); cleaned.append(" ")
            } else {
                cleaned.append(s)
            }
        }
        var tokens: [String] = []
        for word in String(cleaned).split(separator: " ") {
            let normalised = Self.stripAccents(String(word)).lowercased()
            var current = String.UnicodeScalarView()
            for s in normalised.unicodeScalars {
                if Self.isPunctuation(s) {
                    if !current.isEmpty { tokens.append(String(current)); current = String.UnicodeScalarView() }
                    tokens.append(String(s))
                } else {
                    current.append(s)
                }
            }
            if !current.isEmpty { tokens.append(String(current)) }
        }
        return tokens
    }

    // MARK: WordPiece

    private func wordPieces(_ word: String) -> [Int] {
        let chars = Array(word.unicodeScalars)
        if chars.count > Self.maxCharsPerWord { return [unkId] }
        var ids: [Int] = []
        var start = 0
        while start < chars.count {
            var end = chars.count
            var match: Int?
            while start < end {
                var piece = String(String.UnicodeScalarView(chars[start..<end]))
                if start > 0 { piece = "##" + piece }
                if let id = vocab[piece] { match = id; break }
                end -= 1
            }
            guard let id = match else { return [unkId] }
            ids.append(id)
            start = end
        }
        return ids
    }

    // MARK: Character classes (as in the tokenizers crate's BertNormalizer)

    private static func isWhitespace(_ s: Unicode.Scalar) -> Bool {
        s == "\t" || s == "\n" || s == "\r" || s.properties.isWhitespace
    }

    private static func isControl(_ s: Unicode.Scalar) -> Bool {
        if s == "\t" || s == "\n" || s == "\r" { return false }
        switch s.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned: return true
        default: return false
        }
    }

    private static func isPunctuation(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        if (33...47).contains(v) || (58...64).contains(v) || (91...96).contains(v) || (123...126).contains(v) {
            return true
        }
        switch s.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    private static func isCJK(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F,
             0x2B740...0x2B81F, 0x2B820...0x2CEAF, 0xF900...0xFAFF, 0x2F800...0x2FA1F:
            return true
        default:
            return false
        }
    }

    private static func stripAccents(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for s in text.decomposedStringWithCanonicalMapping.unicodeScalars
        where s.properties.generalCategory != .nonspacingMark {
            out.append(s)
        }
        return String(out)
    }
}
