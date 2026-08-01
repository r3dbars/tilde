import Foundation

/// GBNF grammars that force mid-word completions to actually complete the
/// word being typed.
///
/// Measured 2026-08-01 (midword_quiz, n=500, frozen texting exam cut
/// mid-word): unconstrained, the model emits a leading space on 96.6% of
/// mid-word requests — it was fine-tuned exclusively on word-boundary
/// continuations, so "tomo|" reads to it as a finished word. word-1 was
/// 1.2% raw; 41.6% with the letters grammar; 46.0% with the dictionary
/// trie. Client-side filtering cannot recover this (bouncer arm: 1.2%) —
/// the constraint must shape generation, not censor it.
public enum MidwordGrammar {
    /// Alternatives beyond this cap are dropped from the trie grammar;
    /// llama.cpp parses the grammar per-request, so keep it bounded.
    static let maxCompletions = 300

    /// The word fragment the user is mid-way through, or nil at a word
    /// boundary. ASCII letters/apostrophe only — a grammar over a partial
    /// UTF-8 sequence would forbid the very word being typed.
    public static func prefix(of textBeforeCursor: String) -> String? {
        var chars: [Character] = []
        for ch in textBeforeCursor.reversed() {
            guard ch.isASCII, ch.isLetter || ch == "'" else { break }
            chars.append(ch)
            if chars.count > 24 { return nil }
        }
        guard !chars.isEmpty else { return nil }
        return String(chars.reversed())
    }

    /// tail = optional space/punctuation then anything printable; the
    /// cleaner truncates word-completion finals to their first word, so
    /// the tail only needs to be legal, not useful.
    private static let tail = "tail ::= [ .,!?] [ -~]*\n"

    /// Weakest useful constraint: the output must begin with at least one
    /// word character. Forbids the leading-space failure outright.
    public static let letters = "root ::= [a-zA-Z']+ tail?\n" + tail

    /// Strongest constraint: the first word must complete `prefix` into a
    /// word the vocabulary knows. Falls back to `letters` when the
    /// vocabulary has never seen the prefix (new name mid-typing).
    public static func grammar(textBeforeCursor: String,
                               vocabulary: WordVocabulary?) -> String? {
        guard let prefix = prefix(of: textBeforeCursor) else { return nil }
        guard let vocabulary else { return letters }
        let completions = vocabulary.completions(of: prefix, limit: maxCompletions)
        guard !completions.isEmpty else { return letters }
        let alts = completions.map { "\"\($0)\"" }.joined(separator: " | ")
        return "root ::= (\(alts)) tail?\n" + tail
    }
}

/// Sorted-array word list with binary-search prefix lookup. Built from the
/// system dictionary plus the personal lexicon (the owner's names and slang
/// harvested from the training pool — never from exam messages).
public final class WordVocabulary: @unchecked Sendable {
    private let words: [String]          // lowercase, sorted, deduped

    public init(words: [String]) {
        self.words = Array(Set(words.map { $0.lowercased() })).sorted()
    }

    /// System dictionary + optional lexicon file (one word per line).
    public static func load(lexiconURL: URL?) -> WordVocabulary? {
        guard let dict = try? String(contentsOfFile: "/usr/share/dict/words",
                                     encoding: .utf8) else { return nil }
        var all = dict.split(separator: "\n").map(String.init)
        if let lexiconURL,
           let lex = try? String(contentsOf: lexiconURL, encoding: .utf8) {
            all += lex.split(separator: "\n").map(String.init)
        }
        return WordVocabulary(words: all)
    }

    /// Remainders that legally finish `prefix` ("tomo" -> ["rrow", ...]),
    /// shortest first, only GBNF-safe characters.
    public func completions(of prefix: String, limit: Int) -> [String] {
        let p = prefix.lowercased()
        var lo = 0, hi = words.count
        while lo < hi {                  // lower bound of the prefix range
            let mid = (lo + hi) / 2
            if words[mid] < p { lo = mid + 1 } else { hi = mid }
        }
        var out: Set<String> = []
        var i = lo
        while i < words.count, words[i].hasPrefix(p) {
            let rest = String(words[i].dropFirst(p.count))
            if !rest.isEmpty,
               rest.allSatisfy({ ($0.isASCII && $0.isLetter) || $0 == "'" }) {
                out.insert(rest)
            }
            i += 1
        }
        return out.sorted { ($0.count, $0) < ($1.count, $1) }
            .prefix(limit).map { $0 }
    }
}
