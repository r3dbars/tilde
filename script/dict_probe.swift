// Standalone, tunable probe for the instant-dictionary word-completion layer:
// mirrors `dictionaryCompletion(for:)` in
// Sources/InlineGhostIME/GhostInputController.swift EXACTLY when all knobs
// are left at their defaults (same commonWords set, same NSSpellChecker
// call, same two quality rules), so script/dictionary_eval.py can measure
// its real-world accuracy/latency and sweep the heuristics without touching
// the running app, the GPU, or any llama-server process. CPU-only
// (NSSpellChecker), no networking, no file writes outside stdout.
//
// Every heuristic in the shipped function is exposed as an env-var knob:
//
//   STEADYTYPE_DICT_MIN_LETTERS       (default 2)  min prefix length required
//   STEADYTYPE_DICT_MIN_SUFFIX        (default 2)  min added-suffix length
//   STEADYTYPE_DICT_MAX_OBSCURE_LEN   (default 9)  cap on suffix length for a
//                                                   non-common-word candidate
//   STEADYTYPE_DICT_PREFER_COMMON     (default 1)  look for a common-word
//                                                   candidate before falling
//                                                   back to spellchecker's #1
//   STEADYTYPE_DICT_COMMON_ONLY       (default 0)  never complete to a
//                                                   non-common word at all
//   STEADYTYPE_DICT_BLOCK_COMPLETE_COMMON (default 1) don't extend a partial
//                                                   that is already a
//                                                   complete common word
//   STEADYTYPE_DICT_LANGUAGE          (default en)
//
// Protocol: reads word-prefixes from stdin, one per line. For each, prints
// one output line: "<suffix>\t<elapsed_ns>" (suffix may be empty, may
// contain no tab itself). Output line i corresponds to input line i, in
// order — a single long-lived process so NSSpellChecker only warms up once,
// keeping per-call latency realistic and the eval harness fast (no
// per-datapoint process spawn).
//
//   swiftc -O script/dict_probe.swift -o <bin> && <bin> < prefixes.txt
//   STEADYTYPE_DICT_MIN_SUFFIX=3 <bin> < prefixes.txt
import Cocoa

// Keep this set byte-for-byte identical to GhostInputController.commonWords.
let commonWords: Set<String> = Set("""
about after again always another anything around because become before being \
better between change coming could different does doing done during actually \
everything example experience feeling first friend getting going great group \
happen having hello help home hope house idea important interest interesting \
into just keep know language large last later learn least leave life little \
long look love make making many maybe mean meaning meeting might minute moment \
money month more morning most much music must need never new next night nothing \
now number office only other our over own part people perfect person place plan \
please point possible probably problem project put question quick really reason \
remember right same school second see seem send should since small some someone \
something sometimes soon sorry sound start still story sure system take talk \
team tell thank thanks their them then there these thing think this those thought \
three through time today together tomorrow tonight understand until update use \
very want week welcome well what when where which while will with without word \
work working world would write writing wrong year
""".split(whereSeparator: { $0.isWhitespace }).map(String.init))

func envInt(_ name: String, _ def: Int) -> Int {
    if let v = ProcessInfo.processInfo.environment[name], let i = Int(v) { return i }
    return def
}
func envBool(_ name: String, _ def: Bool) -> Bool {
    guard let v = ProcessInfo.processInfo.environment[name] else { return def }
    return ["1", "true", "yes", "on"].contains(v.lowercased())
}
func envString(_ name: String, _ def: String) -> String {
    ProcessInfo.processInfo.environment[name] ?? def
}

let minLetters = envInt("STEADYTYPE_DICT_MIN_LETTERS", 2)
let minSuffix = envInt("STEADYTYPE_DICT_MIN_SUFFIX", 2)
let maxObscureLen = envInt("STEADYTYPE_DICT_MAX_OBSCURE_LEN", 9)
let preferCommon = envBool("STEADYTYPE_DICT_PREFER_COMMON", true)
let commonOnly = envBool("STEADYTYPE_DICT_COMMON_ONLY", false)
let blockCompleteCommon = envBool("STEADYTYPE_DICT_BLOCK_COMPLETE_COMMON", true)
let language = envString("STEADYTYPE_DICT_LANGUAGE", "en")

func dictionaryCompletion(for partial: String) -> String {
    guard partial.count >= minLetters else { return "" }
    let lowerPartial = partial.lowercased()
    if blockCompleteCommon && commonWords.contains(lowerPartial) { return "" }
    let range = NSRange(location: 0, length: (partial as NSString).length)
    let candidates = (NSSpellChecker.shared.completions(
        forPartialWordRange: range,
        in: partial,
        language: language,
        inSpellDocumentWithTag: 0
    ) ?? []).filter { candidate in
        candidate.count >= partial.count + minSuffix
            && candidate.lowercased().hasPrefix(lowerPartial)
    }
    // commonOnly takes priority: the layer is only ever allowed to complete
    // to a common word (or stay silent), regardless of preferCommon.
    if commonOnly {
        if let common = candidates.first(where: { commonWords.contains($0.lowercased()) }) {
            return String(common.dropFirst(partial.count))
        }
        return ""
    }
    if preferCommon, let common = candidates.first(where: { commonWords.contains($0.lowercased()) }) {
        return String(common.dropFirst(partial.count))
    }
    if let first = candidates.first, first.count <= partial.count + maxObscureLen {
        return String(first.dropFirst(partial.count))
    }
    return ""
}

// Warm up NSSpellChecker / the spell-checking XPC service once, untimed, so
// the first real measurement isn't skewed by cold-start connection setup.
_ = dictionaryCompletion(for: "wa")

while let line = readLine(strippingNewline: true) {
    let partial = line
    let start = DispatchTime.now().uptimeNanoseconds
    let suffix = dictionaryCompletion(for: partial)
    let elapsedNs = DispatchTime.now().uptimeNanoseconds - start
    print("\(suffix)\t\(elapsedNs)")
}
