import Foundation

public struct CompletionRequestLifecycle: Equatable, Sendable {
    private var requestGate: SuggestionRequestGate
    public private(set) var currentRequest: CompletionRequest?
    private var streamingPresentationStates: [String: StreamingPresentationState]

    public init(
        requestGate: SuggestionRequestGate = SuggestionRequestGate(),
        currentRequest: CompletionRequest? = nil,
        streamingPresentationStates: [String: StreamingPresentationState] = [:]
    ) {
        self.requestGate = requestGate
        self.currentRequest = currentRequest
        self.streamingPresentationStates = streamingPresentationStates
    }

    public mutating func issue(_ request: CompletionRequest) -> SuggestionRequestTicket {
        currentRequest = request
        streamingPresentationStates[request.suggestionID] = StreamingPresentationState()
        return requestGate.issue(request: request)
    }

    public func allows(_ ticket: SuggestionRequestTicket) -> Bool {
        requestGate.allows(ticket, currentRequest: currentRequest)
    }

    public func streamingState(for suggestionID: String) -> StreamingPresentationState {
        streamingPresentationStates[suggestionID] ?? StreamingPresentationState()
    }

    public mutating func setStreamingState(
        _ state: StreamingPresentationState,
        for suggestionID: String
    ) {
        streamingPresentationStates[suggestionID] = state
    }

    public mutating func clearStreamingState(for suggestionID: String) {
        streamingPresentationStates[suggestionID] = nil
    }

    public mutating func clearStreamingStates() {
        streamingPresentationStates.removeAll(keepingCapacity: true)
    }

    public mutating func invalidate() {
        currentRequest = nil
        clearStreamingStates()
        requestGate.invalidate()
    }
}
