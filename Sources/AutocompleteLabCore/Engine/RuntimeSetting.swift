import Foundation

/// One resolution rule for every tuning knob:
///   1. STEADYTYPE_<NAME> environment variable (eval sweeps, always wins)
///   2. persisted default "steadytype.<NAME>" (survives reboots — the app's
///      REAL configuration; a login-item relaunch must behave identically to
///      a hand-launched tuned session)
///   3. caller's built-in fallback
///
/// Before this existed, the live app's identity (model path, sampler knobs)
/// lived only in the launching shell's environment — one reboot away from
/// silently reverting to a generic model. Trust rule: configuration is state,
/// not incantation.
public enum RuntimeSetting {

    public static func string(_ name: String) -> String? {
        if let env = ProcessInfo.processInfo.environment["STEADYTYPE_" + name], !env.isEmpty {
            return env
        }
        if let stored = UserDefaults.standard.string(forKey: "steadytype." + name), !stored.isEmpty {
            return stored
        }
        return nil
    }

    public static func int(_ name: String) -> Int? { string(name).flatMap(Int.init) }
    public static func double(_ name: String) -> Double? { string(name).flatMap(Double.init) }
}
