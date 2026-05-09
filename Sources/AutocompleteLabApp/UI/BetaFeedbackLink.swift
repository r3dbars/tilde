import Foundation

struct BetaFeedbackLink: Equatable {
    static let issueTemplateURLString =
        "https://github.com/r3dbars/transcripted-autocomplete-lab/issues/new?template=autocomplete-beta-feedback.yml&labels=beta%20feedback,needs%20triage"

    static let menuTitle = "Submit Feedback..."
    static let privacyNote = "Opens the structured beta issue form. Attach only a redacted Privacy Bundle."

    let url: URL

    init(urlString: String = Self.issueTemplateURLString) {
        guard let url = URL(string: urlString) else {
            preconditionFailure("Invalid beta feedback URL")
        }

        self.url = url
    }
}
