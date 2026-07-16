public struct PersonalizationContextPolicy: Equatable, Sendable {
    public init() {}

    public func allows(
        personalCaptureEnabled: Bool,
        captureDecision: PersonalCaptureDecision,
        requestMode: CompletionRequestMode
    ) -> Bool {
        personalCaptureEnabled && captureDecision.canCapture && requestMode.isContinuation
    }
}
