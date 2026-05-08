import Testing
@testable import AutocompleteLabCore

@Suite("AX field classifier")
struct AXFieldClassifierTests {
    private let classifier = AXFieldClassifier()

    @Test("Classifies secure fields")
    func classifiesSecureFields() {
        #expect(classifier.classify(AXFieldClassifierInput(isSecure: true)) == .secure)
        #expect(classifier.classify(AXFieldClassifierInput(placeholder: "Password")) == .secure)
        #expect(classifier.classification(for: AXFieldClassifierInput(placeholder: "One-time code")).reason == "secureHint:one-time code")
        #expect(AXFieldKind.secure.suppressesSuggestionsByDefault)
    }

    @Test("Classifies search and URL fields")
    func classifiesSearchAndURLFields() {
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXSearchField")) == .search)
        #expect(classifier.classify(AXFieldClassifierInput(placeholder: "Search messages")) == .search)
        #expect(classifier.classify(AXFieldClassifierInput(title: "Address Bar")) == .url)
        #expect(AXFieldKind.search.suppressesSuggestionsByDefault)
        #expect(AXFieldKind.url.suppressesSuggestionsByDefault)
    }

    @Test("Classifies form fields")
    func classifiesFormFields() {
        #expect(classifier.classify(AXFieldClassifierInput(placeholder: "Email address")) == .form)
        #expect(classifier.classify(AXFieldClassifierInput(title: "Credit card number")) == .form)
        #expect(classifier.classify(AXFieldClassifierInput(windowTitle: "Login")) == .form)
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXTextField")) == .form)
        #expect(AXFieldKind.form.suppressesSuggestionsByDefault)
    }

    @Test("Classifies unproven web surfaces")
    func classifiesUnprovenWebSurfaces() {
        #expect(classifier.classification(
            for: AXFieldClassifierInput(role: "AXTextArea", windowTitle: "Untitled document - Google Docs")
        ).kind == .unprovenSurface)
        #expect(classifier.classification(
            for: AXFieldClassifierInput(role: "AXTextArea", windowTitle: "Roadmap - Notion")
        ).reason == "unprovenSurface:notion")
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXTextArea", windowTitle: "general - Slack")) == .unprovenSurface)
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXTextArea", windowTitle: "Discord")) == .unprovenSurface)
        #expect(AXFieldKind.unprovenSurface.suppressesSuggestionsByDefault)
    }

    @Test("Classifies compose fields")
    func classifiesComposeFields() {
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXTextArea")) == .multilineCompose)
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXWebArea", textBeforeCursorLength: 12)) == .multilineCompose)
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXTextField", placeholder: "Message", lineCount: 2)) == .multilineCompose)
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXTextField", placeholder: "Message")) == .singlelineCompose)
        #expect(!AXFieldKind.multilineCompose.suppressesSuggestionsByDefault)
        #expect(!AXFieldKind.singlelineCompose.suppressesSuggestionsByDefault)
    }

    @Test("Classifies unknown fields")
    func classifiesUnknownFields() {
        #expect(classifier.classify(AXFieldClassifierInput(role: "AXGroup")) == .unknown)
        #expect(!AXFieldKind.unknown.suppressesSuggestionsByDefault)
    }
}
