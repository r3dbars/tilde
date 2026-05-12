import Foundation

enum AppResidencyPolicy {
    static let automaticTerminationReason = "SteadyType runs as a persistent menu bar agent."
    static let activityOptions: ProcessInfo.ActivityOptions = [.automaticTerminationDisabled]
}
