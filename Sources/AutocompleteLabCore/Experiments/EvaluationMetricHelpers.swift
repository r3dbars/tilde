func evaluationNormalizedWords(_ text: String?) -> [String] {
    guard let text else {
        return []
    }

    return text
        .lowercased()
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .map(String.init)
}

func evaluationContainsContiguous(_ needle: [String], in haystack: [String]) -> Bool {
    guard !needle.isEmpty, haystack.count >= needle.count else {
        return false
    }

    for startIndex in 0...(haystack.count - needle.count) {
        if Array(haystack[startIndex..<(startIndex + needle.count)]) == needle {
            return true
        }
    }

    return false
}

func evaluationRate(_ numerator: Int, _ denominator: Int) -> Double {
    guard denominator > 0 else {
        return 1
    }

    return Double(numerator) / Double(denominator)
}

func evaluationPercent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

func evaluationPercent(_ value: Double, trials: Int) -> String {
    trials > 0 ? evaluationPercent(value) : "n/a"
}
