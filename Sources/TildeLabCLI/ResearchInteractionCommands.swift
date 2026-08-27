import Foundation
import TildeLabKit

extension ResearchCoordinator {
    static func interactionReport(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["campaign", "candidate", "holdout-plan", "input", "output"],
            flags: ["json"]
        )
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "interaction-report"))
        }
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        guard let research = campaign.manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        let candidateID = try arguments.requiredValue("candidate")
        guard let candidate = campaign.manifest.arms.first(where: { $0.id == candidateID }) else {
            throw ResearchCLIError.invalidValue("--candidate")
        }
        let holdoutURL = URL(fileURLWithPath: try arguments.requiredValue("holdout-plan")
            .expandedResearchPath).standardizedFileURL
        let holdoutDigest = try passingHoldoutEvidence(
            planURL: holdoutURL,
            sourceCampaignID: campaign.id,
            championID: research.baselineArmID,
            challengerID: candidateID
        )
        let input = URL(fileURLWithPath: try arguments.requiredValue("input")
            .expandedResearchPath).standardizedFileURL
        let values = try input.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= 8 * 1_024 * 1_024 else {
            throw ResearchCLIError.invalidValue("--input")
        }
        let lines = try Data(contentsOf: input, options: [.mappedIfSafe])
            .split(separator: 0x0A, omittingEmptySubsequences: true)
        guard !lines.isEmpty, lines.count <= 10_000 else {
            throw ResearchCLIError.invalidValue("--input")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let allowedKeys: Set<String> = [
            "schema", "id", "campaignID", "candidateArmID",
            "candidateArmDigestSHA256", "occurredAt", "host", "check", "attempts",
            "failures", "p95Milliseconds", "committedTextCorruptions", "staleInsertions",
        ]
        let records = try lines.enumerated().map { index, line in
            guard line.count <= 16 * 1_024,
                  let object = try JSONSerialization.jsonObject(
                    with: Data(line)
                  ) as? [String: Any],
                  Set(object.keys).isSubset(of: allowedKeys) else {
                throw ResearchCLIError.invalidValue("interaction event line \(index + 1)")
            }
            return try decoder.decode(
                LabInteractionEvidenceRecord.self, from: Data(line)
            ).validated()
        }
        let candidateDigest = try candidate.digestSHA256()
        guard records.allSatisfy({
            $0.campaignID == campaign.id
                && $0.candidateArmID == candidateID
                && $0.candidateArmDigestSHA256 == candidateDigest
        }) else { throw LabInteractionEvidenceError.mixedIdentity }
        let report = try LabInteractionEvidenceAnalyzer.analyze(
            records,
            holdoutEvidenceDigestSHA256: holdoutDigest
        )
        if let path = arguments.value("output") {
            let output = URL(fileURLWithPath: path.expandedResearchPath).standardizedFileURL
            guard !FileManager.default.fileExists(atPath: output.path) else {
                throw ResearchCLIError.usage(
                    "Refusing to overwrite existing interaction report \(output.path)."
                )
            }
            try LabResearchArtifactIO.save(report, to: output)
            ResearchConsole.line("Wrote aggregate-only interaction report: \(output.path)")
        } else if arguments.hasFlag("json") {
            try writeJSON(report)
        } else {
            ResearchConsole.line("Real-host interaction \(report.passed ? "passed" : "not passing")")
            ResearchConsole.line("  records/attempts: \(report.records)/\(report.attempts)")
            ResearchConsole.line(
                "  failures/corruptions/stale insertions: \(report.failures)/\(report.committedTextCorruptions)/\(report.staleInsertions)"
            )
            ResearchConsole.line("  missing checks: \(report.missingCoverage.count)")
            ResearchConsole.line("  limitation: \(report.limitation)")
        }
    }
}
