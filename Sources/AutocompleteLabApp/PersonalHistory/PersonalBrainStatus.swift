import AutocompleteLabCore
import Foundation

struct PersonalBrainStatusReport: Encodable {
    enum State: String, Encodable { case ready, empty, unavailable }
    enum Reason: String, Encodable {
        case ready, storeCorrupt = "store-corrupt", keyUnavailable = "key-unavailable"
        case noCompatibleCheckpoint = "no-compatible-checkpoint"
        case storageUnavailable = "storage-unavailable", internalError = "internal-error"
    }

    let schema = "tilde.personal-brain-status.v1"
    let state: State, reason: Reason
    let captureEnabled: Bool
    let baselineRecipeID, candidateRecipeID: String
    let cutoverMilliseconds: Int64
    let lifetime: Nullable<Aggregate>
    let daily: Nullable<Daily>
    let gates: Nullable<Gates>
    let privacy = Privacy()

    init(
        state: State,
        reason: Reason,
        captureEnabled: Bool,
        checkpoint: PersonalNextWordShadowCheckpoint? = nil
    ) {
        self.state = state
        self.reason = reason
        self.captureEnabled = captureEnabled
        baselineRecipeID = checkpoint?.baselineRecipeID ?? PersonalNextWordShadow.baselineRecipeID
        candidateRecipeID = checkpoint?.candidateRecipeID ?? PersonalNextWordShadow.candidateRecipeID
        cutoverMilliseconds = checkpoint?.evaluationStartMilliseconds
            ?? PersonalNextWordShadow.evaluationStartMilliseconds
        lifetime = checkpoint.map { .value(Aggregate(
            $0.totals, capacityLimited: $0.everCapacityLimited
        )) } ?? .null
        daily = checkpoint.map { .value(Daily(days: $0.activeDays, lifetime: $0.totals)) }
            ?? .null
        gates = checkpoint.map {
            .value(Gates(aggregate: $0.totals, activeDays: $0.activeDays.count))
        } ?? .null
    }

    enum Nullable<Value: Encodable>: Encodable {
        case value(Value), null
        func encode(to encoder: Encoder) throws {
            var output = encoder.singleValueContainer()
            switch self {
            case let .value(value): try output.encode(value)
            case .null: try output.encodeNil()
            }
        }
    }

    struct Aggregate: Encodable {
        let cells: [Int], predictionDisagreements: Int
        let capacityLimited: Bool

        init(_ aggregate: PersonalNextWordPairedAggregate, capacityLimited: Bool) {
            cells = Self.cells(aggregate.outcomeCells)
            predictionDisagreements = aggregate.predictionDisagreements
            self.capacityLimited = capacityLimited
        }

        fileprivate static func cells(_ cells: PersonalNextWordOutcomeCells) -> [Int] {
            // Row-major: baseline silent/correct/wrong by candidate silent/correct/wrong.
            [
                cells.baselineSilentCandidateSilent, cells.baselineSilentCandidateCorrect,
                cells.baselineSilentCandidateWrong, cells.baselineCorrectCandidateSilent,
                cells.baselineCorrectCandidateCorrect, cells.baselineCorrectCandidateWrong,
                cells.baselineWrongCandidateSilent, cells.baselineWrongCandidateCorrect,
                cells.baselineWrongCandidateWrong,
            ]
        }
    }

    struct Daily: Encodable {
        struct Bucket: Encodable {
            let utcDayStartMilliseconds: Int64
            let cells: [Int], predictionDisagreements: Int
        }

        let coversLifetime: Bool
        let buckets: [Bucket]

        init(days: [PersonalNextWordDailyAggregate], lifetime: PersonalNextWordPairedAggregate) {
            let mapped = days.map {
                Bucket(
                    utcDayStartMilliseconds: $0.utcDayStartMilliseconds,
                    cells: Aggregate.cells($0.aggregate.outcomeCells),
                    predictionDisagreements: $0.aggregate.predictionDisagreements
                )
            }
            buckets = mapped
            coversLifetime = (0..<9).allSatisfy { index in
                mapped.reduce(0) { $0 + $1.cells[index] }
                    == Aggregate.cells(lifetime.outcomeCells)[index]
            } && mapped.reduce(0) { $0 + $1.predictionDisagreements }
                == lifetime.predictionDisagreements
        }
    }

    struct Gates: Encodable {
        struct Count: Encodable { let count: Int; let minimum: Int }
        let opportunities, candidatePredictions, predictionDisagreements, activeDays: Count

        init(aggregate: PersonalNextWordPairedAggregate, activeDays: Int) {
            opportunities = Count(
                count: aggregate.opportunities,
                minimum: PersonalNextWordShadowStatus.reportingOpportunityMinimum
            )
            candidatePredictions = Count(
                count: aggregate.candidatePredictions,
                minimum: PersonalNextWordShadowStatus.reportingPredictionMinimum
            )
            predictionDisagreements = Count(
                count: aggregate.predictionDisagreements,
                minimum: PersonalNextWordShadowStatus.reportingDisagreementMinimum
            )
            self.activeDays = Count(
                count: activeDays,
                minimum: PersonalNextWordShadowStatus.reportingActiveDayMinimum
            )
        }
    }

    struct Privacy: Encodable {
        let aggregateOnly = true, localOnly = true
        let containsRawText = false, containsCandidates = false, containsTargets = false,
            containsPerCaseData = false, containsRecordIdentifiers = false, containsPaths = false
    }
}

enum PersonalBrainStatusCommandResult: Equatable { case output(String), failure(String) }

struct PersonalBrainStatusCommand {
    private let settings: TildeSettings; private let store: EncryptedPersonalHistoryStore

    init(
        settings: TildeSettings = TildeSettings(),
        store: EncryptedPersonalHistoryStore = EncryptedPersonalHistoryStore()
    ) {
        self.settings = settings
        self.store = store
    }

    func execute() -> PersonalBrainStatusCommandResult {
        let enabled = settings.personalHistoryEnabled
        guard let historyID = settings.personalHistoryIdentifier,
              let experimentID = settings.personalNextWordExperimentIdentifier else {
            return encode(.init(
                state: .empty, reason: .noCompatibleCheckpoint, captureEnabled: enabled
            ))
        }
        do {
            guard let stored = try store.loadLatestCheckpoint(),
                  stored.matches(
                    historyIdentifier: historyID,
                    experimentIdentifier: experimentID,
                    excludedApps: settings.personalHistoryExcludedApps
                  ), stored.isCompatibleWithCurrentExperiment else {
                return encode(.init(
                    state: .empty, reason: .noCompatibleCheckpoint, captureEnabled: enabled
                ))
            }
            return encode(.init(
                state: .ready, reason: .ready, captureEnabled: enabled,
                checkpoint: stored.checkpoint
            ))
        } catch {
            let report = PersonalBrainStatusReport(
                state: .unavailable, reason: Self.safeReason(for: error), captureEnabled: enabled
            )
            return encode(report, failure: true)
        }
    }

    private func encode(
        _ report: PersonalBrainStatusReport,
        failure: Bool = false
    ) -> PersonalBrainStatusCommandResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(report), let json = String(data: data, encoding: .utf8)
        else { return .failure("{\"reason\":\"internal-error\",\"state\":\"unavailable\"}") }
        return failure ? .failure(json) : .output(json)
    }

    private static func safeReason(for error: any Error) -> PersonalBrainStatusReport.Reason {
        switch error {
        case PersonalHistoryStorageError.corruptStore: .storeCorrupt
        case PersonalHistoryStorageError.invalidKey, PersonalHistoryStorageError.missingKey,
             PersonalHistoryStorageError.keychain: .keyUnavailable
        case is CocoaError, is POSIXError: .storageUnavailable
        default: .internalError
        }
    }
}
