import Testing
@testable import AutocompleteLabCore

@Suite("Visible page context")
struct VisiblePageContextTests {
    @Test("Removes obvious OCR chrome while keeping nearby writing context")
    func removesObviousOCRChrome() throws {
        let context = try #require(VisiblePageContext(text: """
        New chat Search Plugins
        Untitled 13
        Helvetica Regular
        Sam: Can you send the launch note today?
        Draft
        Yeah I can
        """))

        #expect(!context.text.contains("New chat"))
        #expect(!context.text.contains("Untitled 13"))
        #expect(!context.text.contains("Helvetica Regular"))
        #expect(context.text.contains("Sam: Can you send the launch note today?"))
        #expect(context.text.contains("Yeah I can"))
    }

    @Test("Removes embedded OCR chrome from one-line screen captures")
    func removesEmbeddedOCRChrome() throws {
        let context = try #require(VisiblePageContext(text: """
        New chat Search Plugins Automations Projects transcripted-latest Ep quadrant Ep claudebrain Chats Settings Show more Untitled 13 Untitled 35 Helvetica 0 Regular 12 1.0 Sam: Can you send the launch note today? Draft Yeah I can
        """))

        #expect(!context.text.contains("New chat"))
        #expect(!context.text.contains("Plugins Automations Projects"))
        #expect(!context.text.contains("Ep quadrant"))
        #expect(!context.text.contains("Untitled 13"))
        #expect(!context.text.contains("Helvetica 0 Regular"))
        #expect(context.text.contains("Sam: Can you send the launch note today?"))
        #expect(context.text.contains("Yeah I can"))
    }

    @Test("Exposes safe OCR words for instant word completion")
    func exposesSafeOCRWordsForInstantWordCompletion() throws {
        let context = try #require(VisiblePageContext(text: """
        New chat Search Plugins
        SteadyType should recognize Obsidian context
        Transcripted is the product name on the page
        Screen Recording permission appears in Settings
        Draft
        Transcrip
        """))

        #expect(context.completionCandidateWords.contains("Obsidian"))
        #expect(context.completionCandidateWords.contains("Transcripted"))
        #expect(context.completionCandidateWords.contains("permission"))
        #expect(!context.completionCandidateWords.contains("Search"))
        #expect(!context.completionCandidateWords.contains("Settings"))
        #expect(context.traceMetadata["visiblePageContextCompletionCandidateWords"] != "0")
    }

    @Test("Filters active typed line out of OCR context")
    func filtersActiveTypedLineOutOfOCRContext() throws {
        let context = try #require(VisiblePageContext(
            text: """
            Sam: Can you send the launch note today?
            Draft
            Yeah I can send the launch
            Launch notes should stay short
            """,
            excludingActiveTextLine: "Yeah I can send the launch"
        ))

        #expect(context.activeTextLineFiltered)
        #expect(!context.text.contains("Yeah I can send the launch"))
        #expect(context.text.contains("Sam: Can you send the launch note today?"))
        #expect(context.text.contains("Launch notes should stay short"))
        #expect(context.traceMetadata["visiblePageContextActiveLineFiltered"] == "true")
    }

    @Test("Filters OCR line when active text is only a prefix")
    func filtersOCRLineWhenActiveTextIsPrefix() throws {
        let context = try #require(VisiblePageContext(
            text: """
            Project update
            The privacy report should stay redacted before it leaves this Mac
            Useful nearby phrase
            """,
            excludingActiveTextLine: "The privacy report should stay redac"
        ))

        #expect(!context.text.contains("The privacy report should stay redacted"))
        #expect(context.text.contains("Useful nearby phrase"))
    }
}
