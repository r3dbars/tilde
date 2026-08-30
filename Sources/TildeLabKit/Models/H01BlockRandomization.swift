import TildeCore
import Foundation

/// H01 — "three visible words beat eight" — block randomization harness.
///
/// LAB ONLY. Stage 0 has not closed, so no shipped target can enable H01 or
/// carry an arm over the completion wire. This preserves the frozen schedule
/// and arm semantics for review and simulation until F03 actually unlocks the
/// experiment; production keeps each profile's fixed visible-word cap.
///
/// Design:
/// - A *block* is a fixed wall-clock window (30 minutes by default) measured
///   from a persisted epoch. A typing session pins the arm of the block it
///   started in, so one session never changes visible length mid-sentence.
/// - Blocks are drawn as balanced pairs: pair `p` is either `AB` or `BA`,
///   chosen by a seeded, reproducible bit. Every even prefix of the schedule
///   therefore holds exactly as many A blocks as B blocks — permuted-block
///   randomization with block size two.
/// - The seed and epoch are persisted once. A restart re-reads them, so the
///   schedule is never reshuffled underneath a running experiment.
public enum H01Arm: String, Codable, Equatable, Sendable, CaseIterable {
    /// Control: today's production default visible-word cap.
    case a
    /// Treatment: the three-word cap H01 exists to test.
    case b

    public var visibleWordCap: Int {
        switch self {
        case .a: CompletionSuggestion.defaultMaxVisibleWords
        case .b: H01BlockRandomization.treatmentVisibleWordCap
        }
    }

    /// The text-free v3 event already carries champion/challenger. Arm A is
    /// the champion (unchanged production behavior); arm B is the challenger.
    public var eventVariant: String {
        switch self {
        case .a: "champion"
        case .b: "challenger"
        }
    }
}

/// Seeded, reproducible AB/BA block schedule. Value type; no I/O.
public struct H01BlockSchedule: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let defaultBlockSeconds: TimeInterval = 30 * 60
    /// A block shorter than this would split ordinary sentences; a longer one
    /// buys too little balance per dogfood day.
    public static let minimumBlockSeconds: TimeInterval = 60
    public static let maximumBlockSeconds: TimeInterval = 4 * 60 * 60

    public let version: Int
    public let seed: UInt64
    public let epoch: Date
    public let blockSeconds: TimeInterval

    public init(
        seed: UInt64,
        epoch: Date,
        blockSeconds: TimeInterval = H01BlockSchedule.defaultBlockSeconds
    ) {
        version = Self.currentVersion
        self.seed = seed
        self.epoch = epoch
        self.blockSeconds = min(
            Self.maximumBlockSeconds,
            max(Self.minimumBlockSeconds, blockSeconds)
        )
    }

    /// Blocks before the epoch cannot exist; a clock that steps backwards
    /// lands in block zero rather than a negative index.
    public func blockIndex(at date: Date) -> Int {
        let elapsed = date.timeIntervalSince(epoch)
        guard elapsed > 0 else { return 0 }
        return Int(elapsed / blockSeconds)
    }

    public func arm(atBlockIndex index: Int) -> H01Arm {
        let block = max(0, index)
        let pair = UInt64(block / 2)
        let first = Self.pairStartsWithTreatment(seed: seed, pair: pair)
        let isSecondHalf = block % 2 == 1
        // AB or BA — the pair is always one of each.
        return (first != isSecondHalf) ? .b : .a
    }

    public func arm(at date: Date) -> H01Arm {
        arm(atBlockIndex: blockIndex(at: date))
    }

    private static func pairStartsWithTreatment(seed: UInt64, pair: UInt64) -> Bool {
        splitMix64(seed &+ (pair &* 0x9E37_79B9_7F4A_7C15)) & 1 == 1
    }

    private static func splitMix64(_ input: UInt64) -> UInt64 {
        var value = input &+ 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    public func encodedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    public static func decodeJSON(_ value: String) -> H01BlockSchedule? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let schedule = try? decoder.decode(Self.self, from: Data(value.utf8)),
              schedule.version == currentVersion else { return nil }
        return schedule
    }
}

/// Minimal persistence surface for exercising the frozen Lab protocol.
/// Tests use an in-memory double; production does not use this contract.
public protocol H01ExperimentDefaults: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: H01ExperimentDefaults {}

public enum H01BlockRandomization {
    /// Registered protocol key retained for reproducible Lab simulations.
    public static let enabledKey = "H01BlockRandomizationEnabled"
    /// Persisted schedule. Written once, then only read.
    public static let scheduleKey = "H01BlockSchedule"

    public static let treatmentVisibleWordCap = 3

    public static func isEnabled(_ defaults: H01ExperimentDefaults?) -> Bool {
        (defaults?.object(forKey: enabledKey) as? Bool) ?? false
    }

    public static func setEnabled(_ enabled: Bool, in defaults: H01ExperimentDefaults?) {
        defaults?.set(enabled, forKey: enabledKey)
    }

    /// The registered future host profile; this does not enable production.
    public static func isEligible(profile: TildeProductProfile) -> Bool {
        profile == .modelPreview
    }

    /// Reads the persisted schedule, creating and persisting one the first
    /// time. Never reshuffles an existing schedule.
    @discardableResult
    public static func schedule(
        in defaults: H01ExperimentDefaults?,
        now: Date = Date(),
        seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max),
        blockSeconds: TimeInterval = H01BlockSchedule.defaultBlockSeconds
    ) -> H01BlockSchedule {
        if let stored = defaults?.object(forKey: scheduleKey) as? String,
           let schedule = H01BlockSchedule.decodeJSON(stored) {
            return schedule
        }
        let created = H01BlockSchedule(seed: seed, epoch: now, blockSeconds: blockSeconds)
        if let encoded = try? created.encodedJSON() {
            defaults?.set(encoded, forKey: scheduleKey)
        }
        return created
    }

    /// Simulates the arm a future eligible typing session would pin.
    public static func arm(
        profile: TildeProductProfile,
        defaults: H01ExperimentDefaults?,
        now: Date = Date()
    ) -> H01Arm? {
        guard isEligible(profile: profile), isEnabled(defaults) else { return nil }
        return schedule(in: defaults, now: now).arm(at: now)
    }

    /// Resolves the registered Lab arm to its frozen cap. Shipped completion
    /// requests have no arm field and cannot call this path.
    public static func visibleWordCap(
        requestedArm: String?,
        profile: TildeProductProfile,
        defaults: H01ExperimentDefaults?
    ) -> Int? {
        guard isEligible(profile: profile), isEnabled(defaults),
              let requestedArm, let arm = H01Arm(rawValue: requestedArm) else { return nil }
        return arm.visibleWordCap
    }

    /// The only identifiers registered by the Lab protocol.
    public static func isValidArmIdentifier(_ value: String) -> Bool {
        H01Arm(rawValue: value) != nil
    }
}
