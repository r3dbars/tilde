@testable import AutocompleteLabApp
import AutocompleteLabCore
import Testing

@Suite("Acceptance survival task host")
@MainActor
struct AcceptanceSurvivalTaskHostTests {
    @Test("replaces and cancels scheduled checkpoint work")
    func replacesAndCancelsScheduledCheckpointWork() {
        let host = AcceptanceSurvivalTaskHost()

        host.schedule(acceptanceID: "first", start: {}, measure: { _ in })
        #expect(host.scheduledTaskCount == 1)

        host.schedule(acceptanceID: "first", start: {}, measure: { _ in })
        #expect(host.scheduledTaskCount == 1)

        host.cancel(acceptanceID: "first")
        #expect(host.scheduledTaskCount == 0)
    }

    @Test("finishes one acceptance without affecting another")
    func finishesOneAcceptanceWithoutAffectingAnother() {
        let host = AcceptanceSurvivalTaskHost()

        host.schedule(acceptanceID: "first", start: {}, measure: { _ in })
        host.schedule(acceptanceID: "second", start: {}, measure: { _ in })
        host.finish(acceptanceID: "first")

        #expect(host.scheduledTaskCount == 1)
        host.cancel(acceptanceID: "second")
    }
}
