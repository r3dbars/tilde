import TildeCore
import Testing
@testable import TildeLabKit

/// The Lab judge's grounding rule and the live completion path's grounding
/// rule must be the same rule. They are: `LabOutputJudge` delegates to
/// `TildeCore.FactualGroundingPolicy`. These cases pin that, so a future
/// edit that reintroduces a second copy fails here rather than shipping a
/// preview whose filter disagrees with the campaign that nominated it.
@Suite("Lab / product grounding parity")
struct LabGroundingParityTests {
    private struct Fixture {
        let candidate: String
        let typedContext: String
        let scene: ScreenScene.Scene?
        /// Expected under `.numbersAndNames`.
        let isUnsupported: Bool
    }

    private static let scene = ScreenScene.Scene(
        mode: .replying,
        conversationTurns: [
            .init(speaker: .other, text: "can you send the deck before the review?"),
            .init(speaker: .selfSpeaker, text: "yes, sending it Thursday."),
        ],
        referenceSnippets: ["Review is at 4pm in room 12; ping dana@example.com."]
    )

    private static let fixtures: [Fixture] = [
        .init(candidate: "at 4pm", typedContext: "sure, ", scene: scene, isUnsupported: false),
        .init(candidate: "at 9am", typedContext: "sure, ", scene: scene, isUnsupported: true),
        .init(candidate: "in room 12", typedContext: "sure, ", scene: scene, isUnsupported: false),
        .init(candidate: "in room 15", typedContext: "sure, ", scene: scene, isUnsupported: true),
        .init(candidate: "sending it Thursday", typedContext: "", scene: scene, isUnsupported: false),
        .init(candidate: "sending it Monday", typedContext: "", scene: scene, isUnsupported: true),
        .init(candidate: "dana@example.com has it", typedContext: "", scene: scene, isUnsupported: false),
        .init(candidate: "cc priya@example.com", typedContext: "", scene: scene, isUnsupported: true),
        .init(candidate: "ask Marcus about it", typedContext: "", scene: scene, isUnsupported: true),
        .init(candidate: "Great, see you there", typedContext: "", scene: scene, isUnsupported: false),
        .init(candidate: "see you there Great", typedContext: "", scene: scene, isUnsupported: true),
        .init(candidate: "sounds good to me", typedContext: "", scene: scene, isUnsupported: false),
        .init(candidate: "ok thanks", typedContext: "", scene: scene, isUnsupported: false),
        .init(candidate: "at 4pm", typedContext: "the sync is at 4pm and ", scene: nil, isUnsupported: false),
        .init(candidate: "at 5pm", typedContext: "the sync is at 4pm and ", scene: nil, isUnsupported: true),
    ]

    @Test("The judge and the product rule agree on every fixture, in every mode")
    func judgeMatchesProductRule() {
        for mode in [LabFactualGroundingMode.numbersAndNames, .allAnchors] {
            for fixture in Self.fixtures {
                let judged = LabOutputJudge.containsUnsupportedFact(
                    fixture.candidate,
                    typedContext: fixture.typedContext,
                    scene: fixture.scene,
                    mode: mode
                )
                let product = FactualGroundingPolicy.containsUnsupportedFact(
                    fixture.candidate,
                    typedContext: fixture.typedContext,
                    scene: fixture.scene,
                    mode: mode.groundingMode
                )
                #expect(judged == product, "\(mode.rawValue): \(fixture.candidate)")
            }
        }
    }

    /// Without this the parity test could pass on two identically broken
    /// implementations, or on one that never rejects anything.
    @Test("Names-and-numbers verdicts are the ones the campaign measured")
    func verdictsAreNotVacuous() {
        for fixture in Self.fixtures {
            #expect(
                FactualGroundingPolicy.containsUnsupportedFact(
                    fixture.candidate,
                    typedContext: fixture.typedContext,
                    scene: fixture.scene,
                    mode: .numbersAndNames
                ) == fixture.isUnsupported,
                "\(fixture.candidate)"
            )
        }
        #expect(Self.fixtures.contains { $0.isUnsupported })
        #expect(Self.fixtures.contains { !$0.isUnsupported })
    }

    @Test("The 9B preview is the only profile that grounds")
    func onlyPreview9BGrounds() {
        #expect(TildeProductProfile.preview9B.factualGrounding == .numbersAndNames)
        for profile in [TildeProductProfile.production, .preview26B, .modelPreview] {
            #expect(profile.factualGrounding == .off)
        }
    }
}
