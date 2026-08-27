import Foundation

public enum LabResearchThermalLevel: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

public struct LabResearchMachineState: Codable, Equatable, Sendable {
    public let powerSourceKnown: Bool
    public let isOnACPower: Bool
    public let lowPowerModeEnabled: Bool
    public let thermalLevel: LabResearchThermalLevel
    public let checkedAt: Date

    public var blocksStableTiming: Bool {
        !powerSourceKnown || !isOnACPower || lowPowerModeEnabled
            || thermalLevel == .serious || thermalLevel == .critical
            || thermalLevel == .unknown
    }

    public func isStable(allowBattery: Bool) -> Bool {
        let powerReady = allowBattery || (powerSourceKnown && isOnACPower)
        return powerReady
            && !lowPowerModeEnabled
            && thermalLevel != .serious
            && thermalLevel != .critical
            && thermalLevel != .unknown
    }

    public init(
        powerSourceKnown: Bool,
        isOnACPower: Bool,
        lowPowerModeEnabled: Bool,
        thermalLevel: LabResearchThermalLevel,
        checkedAt: Date = Date()
    ) {
        self.powerSourceKnown = powerSourceKnown
        self.isOnACPower = isOnACPower
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.thermalLevel = thermalLevel
        self.checkedAt = checkedAt
    }
}

/// Privacy-safe execution provenance written once per interleaved root block.
/// It contains no scenario, prompt, candidate, application, or document data.
public struct LabResearchBlockEnvironment: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.block-environment.v2"

    public let schema: String
    public let blockIndex: Int
    public let armRunOrder: [String]
    public let workerCount: Int
    public let configuredSlotsPerWorker: Int
    public let candidateCacheEnabled: Bool
    public let runtimeByArm: [String: LabExecutionSnapshot]?
    public let machine: LabResearchMachineState

    public init(
        blockIndex: Int,
        armRunOrder: [String],
        workerCount: Int,
        configuredSlotsPerWorker: Int,
        candidateCacheEnabled: Bool,
        runtimeByArm: [String: LabExecutionSnapshot]? = nil,
        machine: LabResearchMachineState
    ) {
        schema = Self.currentSchema
        self.blockIndex = blockIndex
        self.armRunOrder = armRunOrder
        self.workerCount = workerCount
        self.configuredSlotsPerWorker = configuredSlotsPerWorker
        self.candidateCacheEnabled = candidateCacheEnabled
        self.runtimeByArm = runtimeByArm
        self.machine = machine
    }
}

public enum LabResearchMachinePreflightError: Error, LocalizedError, Equatable, Sendable {
    case unstableMachineState

    public var errorDescription: String? {
        "The campaign paused because AC power, normal power mode, and a safe thermal state are required. Use --allow-battery only for non-comparative diagnostics."
    }
}

/// Aggregate machine gate used between root blocks. It never inspects or logs
/// writing data, and it does not turn power state into a candidate feature.
public enum LabResearchMachinePreflight {
    public static func inspect() -> LabResearchMachineState {
        let battery = command(["-g", "batt"])
        let known = battery.localizedCaseInsensitiveContains("AC Power")
            || battery.localizedCaseInsensitiveContains("Battery Power")
        let thermal: LabResearchThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .unknown
        }
        return LabResearchMachineState(
            powerSourceKnown: known,
            isOnACPower: battery.localizedCaseInsensitiveContains("AC Power"),
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalLevel: thermal
        )
    }

    public static func waitUntilStable(
        allowBattery: Bool,
        pollNanoseconds: UInt64 = 30_000_000_000,
        stateObserved: @escaping @Sendable (LabResearchMachineState) async -> Void = { _ in }
    ) async throws {
        while true {
            try Task.checkCancellation()
            let state = inspect()
            await stateObserved(state)
            if state.isStable(allowBattery: allowBattery) { return }
            guard pollNanoseconds > 0 else {
                throw LabResearchMachinePreflightError.unstableMachineState
            }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }
    }

    private static func command(_ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        } catch {
            return ""
        }
    }
}
