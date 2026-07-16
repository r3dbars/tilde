import Foundation
import AutocompleteLabCore

struct PersonalizationSelection: Sendable {
    let context: PersonalContext?
    let memory: PersonalWritingMemory?

    static let empty = PersonalizationSelection(context: nil, memory: nil)
}

@MainActor
final class PersonalizationCoordinator {
    private let indexer: PersonalWritingMemoryIndexer
    private let capturePolicy: PersonalCapturePolicy
    private let contextPolicy: PersonalizationContextPolicy
    private var rebuildTimer: Timer?
    private var cachedFieldKey: String?
    private var cachedContext: PersonalContext?
    private var cachedMemoryRevision: UInt64?

    init(
        indexer: PersonalWritingMemoryIndexer = .shared,
        capturePolicy: PersonalCapturePolicy = PersonalCapturePolicy(),
        contextPolicy: PersonalizationContextPolicy = PersonalizationContextPolicy()
    ) {
        self.indexer = indexer
        self.capturePolicy = capturePolicy
        self.contextPolicy = contextPolicy
    }

    func selection(
        isEnabled: Bool,
        context: FocusedTextContext,
        appBundleIdentifier: String,
        fieldClassification: AXFieldClassification,
        requestMode: CompletionRequestMode
    ) -> PersonalizationSelection {
        let captureDecision = capturePolicy.decision(for: PersonalCaptureInput(
            bundleIdentifier: appBundleIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            isSecure: context.isSecure,
            fieldClassification: fieldClassification
        ))
        let snapshot = indexer.currentSnapshot()
        guard contextPolicy.allows(
            personalCaptureEnabled: isEnabled,
            captureDecision: captureDecision,
            requestMode: requestMode
        ), let memory = snapshot.memory else {
            return .empty
        }
        let fieldKey = "\(appBundleIdentifier)|\(context.elementIdentifier)"
        if cachedFieldKey == fieldKey,
           cachedMemoryRevision == snapshot.revision,
           let cachedContext {
            return PersonalizationSelection(context: cachedContext, memory: memory)
        }
        let personalContext = memory.personalContext(for: PersonalContextQuery(
            textBeforeCursor: context.textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier
        ))
        cachedFieldKey = personalContext == nil ? nil : fieldKey
        cachedContext = personalContext
        cachedMemoryRevision = personalContext == nil ? nil : snapshot.revision
        return PersonalizationSelection(
            context: personalContext,
            memory: memory
        )
    }

    func refreshIndexing(isEnabled: Bool) {
        rebuildTimer?.invalidate()
        rebuildTimer = nil
        cachedFieldKey = nil
        cachedContext = nil
        cachedMemoryRevision = nil
        guard isEnabled else { return }
        indexer.rebuild()
        let timer = Timer(timeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.indexer.rebuild() }
        }
        RunLoop.main.add(timer, forMode: .common)
        rebuildTimer = timer
    }

    func stop() {
        rebuildTimer?.invalidate()
        rebuildTimer = nil
    }

    func deleteAll() {
        stop()
        indexer.deleteAll()
    }
}
