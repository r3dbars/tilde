import Foundation

enum AppResidencyPolicy {
    static let automaticTerminationReason = "Tilde runs as a persistent menu bar agent."
    static let activityOptions: ProcessInfo.ActivityOptions = [.automaticTerminationDisabled]
}
