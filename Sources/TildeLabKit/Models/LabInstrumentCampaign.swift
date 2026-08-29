import Foundation
import TildeCore

/// Built-in F03 instrument campaign. No campaign JSON required.
/// Events stay text-free. The local word diary is never ingested here.
public enum LabInstrumentCampaign {
    public static let id = TextFreeOnlineEvent.instrumentCampaignID
    public static let name = "F03 instrument"

    public static func defaultEventURL() -> URL {
        TextFreeOnlineEventFile.url(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            supportDirectoryName: TildeProductProfile.current.supportDirectoryName
        )
    }

    /// Local block randomization is 50/50 by construction, so a plan that
    /// admits a displayed challenger declares the frozen safety evidence the
    /// ramp rule requires. Ingest stays shadow — champion only, never a
    /// displayed challenger — until arm-tagged events actually arrive.
    public static let armedSafetyEvidenceDigestSHA256 = String(repeating: "e", count: 64)

    public static func makePlan(
        covering dates: [Date],
        now: Date = Date(),
        includesChallenger: Bool = false
    ) throws -> LabOnlineExperimentPlan {
        let earliest = dates.min() ?? now
        let start = earliest.addingTimeInterval(-60)
        let end = start.addingTimeInterval(31 * 86_400)
        return try LabOnlineExperimentPlan(
            campaignID: id,
            phase: includesChallenger ? .dogfood : .shadow,
            championArmID: "champion",
            championArmDigestSHA256: String(repeating: "c", count: 64),
            challengerArmID: "challenger",
            challengerArmDigestSHA256: String(repeating: "d", count: 64),
            challengerAllocation: includesChallenger ? 0.5 : 0,
            startsAt: start,
            endsAt: end,
            safetyEvidenceDigestSHA256: includesChallenger
                ? armedSafetyEvidenceDigestSHA256
                : nil
        ).validated()
    }

    /// True when a batch carries at least one arm-tagged challenger event —
    /// the H01 harness running — so ingest needs a plan that permits display.
    public static func includesChallenger(_ events: [LabOnlineExperimentEvent]) -> Bool {
        events.contains { $0.variant == .challenger }
    }

    public static func ensureReady(
        database: LabResearchDatabase,
        covering dates: [Date],
        now: Date = Date(),
        includesChallenger: Bool = false
    ) async throws -> LabOnlineExperimentPlan {
        try await database.registerCampaign(
            LabResearchCampaignRecord(
                id: id,
                name: name,
                manifestDigestSHA256: String(repeating: "a", count: 64),
                suiteDigestSHA256: String(repeating: "b", count: 64),
                modelSHA256: String(repeating: "c", count: 64),
                helperSHA256: String(repeating: "d", count: 64),
                gitCommit: "instrument",
                protocolDefinition: LabResearchProtocol(
                    phase: .shadow,
                    experimentClass: .runtime,
                    baselineArmID: "champion",
                    fixedGenerationSeeds: [0]
                )
            )
        )
        let plan = try makePlan(covering: dates, now: now, includesChallenger: includesChallenger)
        if let existing = try await database.onlinePlan(campaignID: id) {
            let stored = try await database.onlineEvents(campaignID: id)
            let covered = dates.allSatisfy { $0 >= existing.startsAt && $0 <= existing.endsAt }
            if covered, existing.phase == plan.phase { return existing }
            if covered, existing.phase == .shadow, plan.phase == .dogfood {
                // The first arm-tagged batch arrived. Widen the same window
                // from shadow to dogfood: stored champion-only events stay
                // valid, so no telemetry has to be deleted to start H01.
                let armed = try LabOnlineExperimentPlan(
                    campaignID: id,
                    phase: .dogfood,
                    championArmID: existing.championArmID,
                    championArmDigestSHA256: existing.championArmDigestSHA256,
                    challengerArmID: existing.challengerArmID,
                    challengerArmDigestSHA256: existing.challengerArmDigestSHA256,
                    challengerAllocation: 0.5,
                    startsAt: existing.startsAt,
                    endsAt: existing.endsAt,
                    safetyEvidenceDigestSHA256: armedSafetyEvidenceDigestSHA256
                ).validated()
                try await database.saveOnlinePlan(armed)
                return armed
            }
            if covered { return existing }
            if stored.isEmpty {
                try await database.saveOnlinePlan(plan)
                return plan
            }
            throw LabOnlineExperimentError.invalidWindow
        }
        try await database.saveOnlinePlan(plan)
        return plan
    }
}
