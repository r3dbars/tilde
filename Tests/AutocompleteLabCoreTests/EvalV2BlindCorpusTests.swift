import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Eval v2 blind corpus")
struct EvalV2BlindCorpusTests {
    @Test("Default plan separates public-domain prompts from hidden answer key")
    func defaultPlanSeparatesPromptsFromAnswerKey() throws {
        let plan = EvalV2BlindCorpus.makePlan()

        #expect(plan.validationIssues.isEmpty)
        #expect(plan.isReadyForCollection)
        #expect(!plan.containsScoredResults)
        #expect(plan.prompts.count == plan.answerKey.count)
        #expect(plan.publicDomainCaseCount >= EvalV2BlindCorpus.minimumPublicDomainCaseCount)
        #expect(plan.adversarialCaseCount >= EvalV2BlindCorpus.minimumAdversarialCaseCount)
        #expect(plan.publicDomainSourceCount >= EvalV2BlindCorpus.minimumPublicDomainCaseCount)

        let promptsByID = Dictionary(uniqueKeysWithValues: plan.prompts.map { ($0.caseID, $0) })
        for answer in plan.answerKey {
            let prompt = try #require(promptsByID[answer.caseID])
            if let expectedContinuation = answer.expectedContinuation {
                #expect(!prompt.textBeforeCursor.contains(expectedContinuation))
            }
            #expect(prompt.caseID == answer.caseID)
        }
    }

    @Test("Public-domain cases cite external source and adversarial cases suppress")
    func publicDomainCasesCiteSourcesAndAdversarialCasesSuppress() {
        let answerKey = EvalV2BlindCorpus.answerKey()
        let publicDomain = answerKey.filter { $0.kind == .publicDomainContinuation }
        let adversarial = answerKey.filter { $0.kind == .adversarialSuppression }

        #expect(publicDomain.allSatisfy { $0.expectedAction == .displayContinuation })
        #expect(publicDomain.allSatisfy { $0.expectedContinuation?.isEmpty == false })
        #expect(publicDomain.allSatisfy { $0.source?.url.hasPrefix("https://") == true })
        #expect(publicDomain.allSatisfy { $0.source?.publicDomainBasis.isEmpty == false })

        #expect(adversarial.allSatisfy { $0.expectedAction == .suppressSuggestion })
        #expect(adversarial.allSatisfy { $0.expectedContinuation == nil })
        #expect(adversarial.allSatisfy { $0.source == nil })
        #expect(adversarial.allSatisfy { !$0.riskTags.isEmpty })
    }

    @Test("Validation rejects fake scored or underspecified corpus rows")
    func validationRejectsUnderspecifiedRows() {
        let issues = EvalV2BlindCorpus.validationIssues(for: [
            EvalV2BlindCorpusCase(
                id: "missing-source",
                kind: .publicDomainContinuation,
                textBeforeCursor: "A public row should cite",
                expectedContinuation: "source"
            ),
            EvalV2BlindCorpusCase(
                id: "bad-adversarial",
                kind: .adversarialSuppression,
                textBeforeCursor: "Password:",
                expectedContinuation: "hunter2"
            )
        ])

        #expect(issues.contains("missing public-domain source: missing-source"))
        #expect(issues.contains("adversarial case should not include a continuation: bad-adversarial"))
        #expect(issues.contains("missing adversarial risk tag: bad-adversarial"))
        #expect(issues.contains("needs at least 8 public-domain cases"))
        #expect(issues.contains("needs at least 8 adversarial cases"))
    }
}
