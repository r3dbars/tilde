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
}
