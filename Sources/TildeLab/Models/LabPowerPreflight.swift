import Foundation

struct LabPowerPreflight: Equatable {
    let isOnACPower: Bool
    let mode: String
    let checkedAt: Date

    var isRecommended: Bool { isOnACPower && mode == "High Power" }

    var message: String {
        if isRecommended { return "AC power · High Power mode" }
        if !isOnACPower { return "Connect power before a long campaign" }
        return "Use High Power mode for stable long-run timing"
    }

    static func inspect() -> LabPowerPreflight {
        let battery = command(["-g", "batt"])
        let custom = command(["-g", "custom"])
        let onAC = battery.localizedCaseInsensitiveContains("AC Power")
        let mode: String
        if custom.range(of: #"powermode\s+2"#, options: .regularExpression) != nil {
            mode = "High Power"
        } else if custom.range(of: #"powermode\s+0"#, options: .regularExpression) != nil {
            mode = "Low Power"
        } else {
            mode = "Automatic"
        }
        return LabPowerPreflight(isOnACPower: onAC, mode: mode, checkedAt: Date())
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
