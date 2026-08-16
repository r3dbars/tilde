import Foundation

/// Deterministic, regex/checksum-based secret detection for text that is
/// about to be persisted or joined into a completion prompt. This is the
/// RULES layer only — a fast, fully-tested first pass over structurally
/// recognizable secrets (credit cards, IBANs, SSNs, API-key shapes, JWTs,
/// PEM blocks) plus optionally email/phone. A model-based layer (GLiNER)
/// runs after this, app-side, to catch freeform PII the rules can't see
/// structurally. Everything here is pure and has no knowledge of where the
/// text came from or where it is going.
public enum SecretRules {
    /// The shape a rule matched. Used both to label the replacement token
    /// and to identify which rule fired in a `Finding`. Several distinct
    /// rules (AWS/OpenAI/GitHub/generic high-entropy) share `.apiKey`
    /// because the plan groups them as one "API-key shapes" concept and the
    /// persisted token should not advertise which provider leaked.
    public enum SecretType: String, Equatable, Sendable, CaseIterable {
        case creditCard = "card"
        case iban = "iban"
        case ssn = "ssn"
        case apiKey = "api-key"
        case jwt = "jwt"
        case pem = "pem"
        case email = "email"
        case phone = "phone"
    }

    /// One accepted redaction. Carries only the type, never the matched
    /// text — findings are safe to log or count.
    public struct Finding: Equatable, Sendable {
        public let type: SecretType

        public init(type: SecretType) {
            self.type = type
        }
    }

    /// Which optional categories participate. Structured secrets (card,
    /// IBAN, SSN, API-key shapes, JWT, PEM) are always scrubbed regardless
    /// of this config — only email/phone are configurable, since they are
    /// also genuinely useful personal vocabulary.
    public struct ScrubConfig: Equatable, Sendable {
        public var scrubEmails: Bool
        public var scrubPhones: Bool

        public init(scrubEmails: Bool, scrubPhones: Bool) {
            self.scrubEmails = scrubEmails
            self.scrubPhones = scrubPhones
        }

        /// Text about to be written into the encrypted Personal History
        /// store. Default per the Screen Memory plan: scrub emails/phones.
        public static let forPersistence = ScrubConfig(scrubEmails: true, scrubPhones: true)

        /// Text about to join a completion prompt (never written to disk
        /// from this path). Structured secrets still never survive; email
        /// and phone are kept since they can be genuinely useful context.
        public static let forPromptContext = ScrubConfig(scrubEmails: false, scrubPhones: false)
    }

    private static let replacementOpen = "\u{27E8}redacted:"
    private static let replacementClose = "\u{27E9}"

    /// Scrubs every recognized secret out of `text`, replacing each with a
    /// `⟨redacted:type⟩` token. Matches from different rules never overlap
    /// in the result: when two rules claim the same span the earliest,
    /// then longest, then highest-priority match wins and the rest are
    /// dropped rather than double-redacted.
    public static func scrub(_ text: String, config: ScrubConfig = .forPersistence) -> (clean: String, findings: [Finding]) {
        guard !text.isEmpty else { return (text, []) }

        var candidates: [(range: Range<String.Index>, type: SecretType, priority: Int)] = []
        for rule in rules(for: config) {
            for range in rule.matches(text) where !range.isEmpty {
                candidates.append((range, rule.type, rule.priority))
            }
        }
        guard !candidates.isEmpty else { return (text, []) }

        candidates.sort { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
            let lhsLength = text.distance(from: lhs.range.lowerBound, to: lhs.range.upperBound)
            let rhsLength = text.distance(from: rhs.range.lowerBound, to: rhs.range.upperBound)
            if lhsLength != rhsLength { return lhsLength > rhsLength }
            return lhs.priority < rhs.priority
        }

        var accepted: [(range: Range<String.Index>, type: SecretType)] = []
        var cursor = text.startIndex
        for candidate in candidates where candidate.range.lowerBound >= cursor {
            accepted.append((candidate.range, candidate.type))
            cursor = candidate.range.upperBound
        }
        guard !accepted.isEmpty else { return (text, []) }

        var clean = ""
        var findings: [Finding] = []
        var walker = text.startIndex
        for match in accepted {
            clean += text[walker..<match.range.lowerBound]
            clean += replacementOpen + match.type.rawValue + replacementClose
            findings.append(Finding(type: match.type))
            walker = match.range.upperBound
        }
        clean += text[walker...]
        return (clean, findings)
    }

    // MARK: - Rule table

    private struct Rule {
        let type: SecretType
        let priority: Int
        let matches: (String) -> [Range<String.Index>]
    }

    private static func rules(for config: ScrubConfig) -> [Rule] {
        var list: [Rule] = [
            Rule(type: .pem, priority: 0, matches: pemMatches),
            Rule(type: .jwt, priority: 1, matches: jwtMatches),
            Rule(type: .iban, priority: 2, matches: ibanMatches),
            Rule(type: .creditCard, priority: 3, matches: creditCardMatches),
            Rule(type: .ssn, priority: 4, matches: ssnMatches),
            Rule(type: .apiKey, priority: 5, matches: awsAccessKeyMatches),
            Rule(type: .apiKey, priority: 6, matches: openAIKeyMatches),
            Rule(type: .apiKey, priority: 7, matches: githubTokenMatches),
            Rule(type: .apiKey, priority: 8, matches: highEntropyTokenMatches),
        ]
        if config.scrubEmails {
            list.append(Rule(type: .email, priority: 9, matches: emailMatches))
        }
        if config.scrubPhones {
            list.append(Rule(type: .phone, priority: 10, matches: phoneMatches))
        }
        return list
    }

    // MARK: - Individual rules

    private static func pemMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"-----BEGIN [A-Z0-9 ]+-----[\s\S]+?-----END [A-Z0-9 ]+-----"#
        )
    }

    private static func jwtMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"#
        )
    }

    /// Custom scan rather than a single greedy regex: a regex with an
    /// optional space between 2–4 char groups has no way to know when to
    /// stop, so it happily eats into whatever ordinary prose follows the
    /// real IBAN. Instead this walks forward from each `LL99` header,
    /// collecting alphanumeric characters (allowing single spaces as group
    /// separators, matching printed IBAN formatting) up to the 34-character
    /// maximum, then tries the mod-97 checksum at the shortest length ≥15
    /// first — the real IBAN boundary — so it never over-consumes into
    /// unrelated text that happens to look alnum-ish.
    private static func ibanMatches(_ text: String) -> [Range<String.Index>] {
        let headers = regexMatches(text, pattern: #"\b[A-Za-z]{2}\d{2}"#)
        var results: [Range<String.Index>] = []
        for header in headers {
            var alnum: [(character: Character, index: String.Index)] = []
            var index = header.lowerBound
            var sawSpace = false
            while index < text.endIndex, alnum.count < 34 {
                let char = text[index]
                if char.isLetter || char.isNumber {
                    alnum.append((char, index))
                    sawSpace = false
                } else if char == " ", !sawSpace, !alnum.isEmpty {
                    sawSpace = true
                } else {
                    break
                }
                index = text.index(after: index)
            }
            guard alnum.count >= 15 else { continue }
            for length in 15...alnum.count where isValidIBAN(String(alnum.prefix(length).map(\.character))) {
                let endIndex = text.index(after: alnum[length - 1].index)
                results.append(header.lowerBound..<endIndex)
                break
            }
        }
        return results
    }

    private static func creditCardMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"(?<!\d)\d(?:[ -]?\d){11,18}(?!\d)"#,
            validate: isValidLuhn
        )
    }

    private static func ssnMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)"#,
            validate: isValidSSNShape
        )
    }

    private static func awsAccessKeyMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(text, pattern: #"\bAKIA[0-9A-Z]{16}\b"#)
    }

    private static func openAIKeyMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(text, pattern: #"\bsk-[A-Za-z0-9_-]{20,}\b"#)
    }

    private static func githubTokenMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(text, pattern: #"\bgh[pousr]_[A-Za-z0-9]{36,}\b"#)
    }

    /// Generic high-entropy token, ≥32 characters with no whitespace, drawn
    /// from a base64-ish alphabet. Gated on character-class diversity and
    /// Shannon entropy so long English words, URLs, hex hashes, and UUIDs
    /// (all low-diversity or low-entropy) don't trip it — see the
    /// false-positive corpus test.
    private static func highEntropyTokenMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"\b[A-Za-z0-9+/_=-]{32,}\b"#,
            validate: isHighEntropySecretShape
        )
    }

    private static func emailMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b"#
        )
    }

    /// Requires an explicit separator between digit groups (space, dot,
    /// dash, or parens around the area code) so a bare 10-digit run — an
    /// order number, an ID — never matches.
    private static func phoneMatches(_ text: String) -> [Range<String.Index>] {
        regexMatches(
            text,
            pattern: #"(?<!\d)(?:\+1[-.\s])?\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}(?!\d)"#
        )
    }

    // MARK: - Validators

    private static func isValidLuhn(_ raw: String) -> Bool {
        let digits = raw.compactMap(\.wholeNumberValue).filter { $0 >= 0 && $0 <= 9 }
        let digitCount = raw.filter(\.isNumber).count
        guard (13...19).contains(digitCount), digitCount == digits.count else { return false }
        var sum = 0
        var alternate = false
        for digit in digits.reversed() {
            var value = digit
            if alternate {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
            alternate.toggle()
        }
        return sum % 10 == 0
    }

    private static func isValidSSNShape(_ raw: String) -> Bool {
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let area = Int(parts[0]), let group = Int(parts[1]), let serial = Int(parts[2]) else {
            return false
        }
        guard area != 0, area != 666, area < 900 else { return false }
        guard group != 0 else { return false }
        guard serial != 0 else { return false }
        return true
    }

    private static func isValidIBAN(_ raw: String) -> Bool {
        let iban = raw.uppercased()
        guard (15...34).contains(iban.count) else { return false }
        guard iban.prefix(2).allSatisfy(\.isLetter), iban.dropFirst(2).prefix(2).allSatisfy(\.isNumber) else {
            return false
        }
        let rearranged = iban.dropFirst(4) + iban.prefix(4)
        var remainder = 0
        for char in rearranged {
            let value: Int
            if let digit = char.wholeNumberValue, char.isNumber {
                value = digit
            } else if char.isLetter, let ascii = char.asciiValue {
                value = Int(ascii) - Int(Character("A").asciiValue!) + 10
            } else {
                return false
            }
            for digit in String(value) {
                guard let d = digit.wholeNumberValue else { return false }
                remainder = (remainder * 10 + d) % 97
            }
        }
        return remainder == 1
    }

    /// `-` is deliberately NOT a diversity class of its own: it's the one
    /// base64url symbol that also shows up constantly in ordinary hyphenated
    /// text (UUIDs, ISO dates, invoice numbers, git hashes-with-dashes), so
    /// counting it would make those false-positive. True base64 punctuation
    /// (`+ / _ =`) still counts, and real secrets are almost always mixed
    /// upper/lower/digit anyway, so this costs little real recall.
    private static func isHighEntropySecretShape(_ raw: String) -> Bool {
        guard raw.count >= 32 else { return false }
        var hasUpper = false, hasLower = false, hasDigit = false, hasSymbol = false
        for char in raw {
            if char.isUppercase { hasUpper = true }
            else if char.isLowercase { hasLower = true }
            else if char.isNumber { hasDigit = true }
            else if "+/_=".contains(char) { hasSymbol = true }
        }
        let classCount = [hasUpper, hasLower, hasDigit, hasSymbol].filter { $0 }.count
        guard classCount >= 3 else { return false }
        return shannonEntropyPerCharacter(raw) >= 3.0
    }

    private static func shannonEntropyPerCharacter(_ s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for char in s { counts[char, default: 0] += 1 }
        let total = Double(s.count)
        return counts.values.reduce(0.0) { accumulated, count in
            let probability = Double(count) / total
            return accumulated - probability * log2(probability)
        }
    }

    // MARK: - Regex plumbing

    private static func regexMatches(
        _ text: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        validate: (String) -> Bool = { _ in true }
    ) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        var results: [Range<String.Index>] = []
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match, let range = Range(match.range, in: text) else { return }
            if validate(String(text[range])) {
                results.append(range)
            }
        }
        return results
    }
}
