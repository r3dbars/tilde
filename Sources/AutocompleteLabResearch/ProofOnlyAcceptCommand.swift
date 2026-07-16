import Foundation

enum ProofOnlyAcceptCommand {
    static let argument = "--proof-only-accept-next-word"
    static let enabledEnvironmentKey = "AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS"
    static let notificationName = Notification.Name("com.steadytype.proof-only.accept-next-word")

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let rawValue = environment[enabledEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !rawValue.isEmpty else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(rawValue)
    }

    static func run(environment: [String: String] = ProcessInfo.processInfo.environment) -> Int32 {
        guard isEnabled(environment: environment) else {
            FileHandle.standardError.write(
                Data("proof-only accept command refused: AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS is not enabled.\n".utf8)
            )
            return 64
        }

        return post()
    }

    static func post() -> Int32 {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [
                "action": "acceptNextWord",
                "source": "proofOnlyAcceptCommand"
            ],
            deliverImmediately: true
        )
        return 0
    }
}
