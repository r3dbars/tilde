import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Beta feedback link")
struct BetaFeedbackLinkTests {
    @Test("Feedback link opens the structured issue form without private payload")
    func feedbackLinkOpensStructuredIssueFormWithoutPrivatePayload() {
        let link = BetaFeedbackLink()
        let url = link.url.absoluteString

        #expect(link.url.scheme == "https")
        #expect(link.url.host == "github.com")
        #expect(url.contains("r3dbars/transcripted-autocomplete-lab/issues/new"))
        #expect(url.contains("template=autocomplete-beta-feedback.yml"))
        #expect(url.contains("labels=beta%20feedback,needs%20triage"))
        #expect(!url.localizedCaseInsensitiveContains("typed"))
        #expect(!url.localizedCaseInsensitiveContains("trace"))
        #expect(!url.localizedCaseInsensitiveContains("screenshot"))
        #expect(BetaFeedbackLink.menuTitle == "Submit Feedback...")
        #expect(BetaFeedbackLink.privacyNote.contains("redacted Privacy Bundle"))
    }
}
