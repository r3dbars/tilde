import Foundation

public struct SuggestionRequestTicket: Equatable, Sendable {
    public let generation: Int
    public let request: CompletionRequest

    public init(generation: Int, request: CompletionRequest) {
        self.generation = generation
        self.request = request
    }
}

public struct SuggestionRequestGate: Equatable, Sendable {
    public private(set) var generation: Int

    public init(generation: Int = 0) {
        self.generation = generation
    }

    public mutating func issue(request: CompletionRequest) -> SuggestionRequestTicket {
        generation += 1
        return SuggestionRequestTicket(generation: generation, request: request)
    }

    public mutating func invalidate() {
        generation += 1
    }

    public func allows(_ ticket: SuggestionRequestTicket, currentRequest: CompletionRequest?) -> Bool {
        ticket.generation == generation && currentRequest == ticket.request
    }
}
