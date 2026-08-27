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

    public static func makePlan(covering dates: [Date], now: Date = Date()) throws -> LabOnlineExperimentPlan {
        let earliest = dates.min() ?? now
        let start = earliest.addingTimeInterval(-60)
        let end = start.addingTimeInterval(31 * 86_400)
        return try LabOnlineExperimentPlan(
            campaignID: id,
            phase: .shadow,
            championArmID: "champion",
            championArmDigestSHA256: String(repeating: "c", count: 64),
            challengerArmID: "challenger",
            challengerArmDigestSHA256: String(repeating: "d", count: 64),
            challengerAllocation: 0,
            startsAt: start,
            endsAt: end
        ).validated()
    }

    public static func ensureReady(
        database: LabResearchDatabase,
        covering dates: [Date],
        now: Date = Date()
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
        let plan = try makePlan(covering: dates, now: now)
        if let existing = try await database.onlinePlan(campaignID: id) {
            let stored = try await database.onlineEvents(campaignID: id)
            let covered = dates.allSatisfy { $0 >= existing.startsAt && $0 <= existing.endsAt }
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
