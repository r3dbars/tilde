import TildeCore
import Foundation

/// Side-effect recorder next to the IME. It does not change marked text.
///
/// Writes two local files:
/// - text-free v3 events for Lab ingest
/// - a word diary the owner can delete, which Lab must never ingest
enum GhostOutcomeLedger {
    private static let io = DispatchQueue(label: "com.tilde.outcome-ledger", qos: .utility)
    private static let lock = NSLock()
    private static var opportunity: LiveOnlineOpportunity?
    private static var watches: [PendingRetainedWatch] = []
    private static var lastActivity = Date.distantPast
    private static var contextProvider: (@Sendable () -> String?)?
    private static var excluded = false
    private static var seenGeneration: Int?
    /// Writing volume between ghosts; see `OpportunityCharacterMeter`.
    private static var meter = OpportunityCharacterMeter()

    static func configure(contextProvider: @escaping @Sendable () -> String?) {
        lock.lock()
        self.contextProvider = contextProvider
        meter.reset()
        lock.unlock()
    }

    /// `register` and `source` are the app's receipt for this ghost (or the
    /// dictionary path's own values); the ledger never derives a register
    /// from the host bundle.
    static func noteShown(
        sessionIdentifier: String,
        register: ContinuationRegister,
        source: TextFreeCandidateSource,
        candidateCharacters: Int,
        candidateWordCount: Int,
        precedingCharacter: Character?,
        excluded: Bool,
        variant: String = "champion",
        at time: Date = Date()
    ) {
        _ = dropIfWiped()
        closeOpenOpportunity(at: time)
        lock.lock()
        self.excluded = excluded
        guard !excluded else {
            opportunity = nil
            meter.reset()
            lastActivity = time
            lock.unlock()
            return
        }
        let opportunityCharacters = meter.takeForOpportunity()
        opportunity = LiveOnlineOpportunity(
            shownAt: time,
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(
                sessionIdentifier: sessionIdentifier
            ),
            variant: variant,
            appCategory: TextFreeAppCategory.from(register: register).rawValue,
            register: register.rawValue,
            boundary: TextFreeCursorBoundary.from(precedingCharacter: precedingCharacter).rawValue,
            safeOpportunity: !excluded,
            candidateCharacters: candidateCharacters,
            candidateWordCount: candidateWordCount,
            candidateSource: source,
            opportunityCharacters: opportunityCharacters
        )
        lastActivity = time
        lock.unlock()
    }

    static func noteVisibleCandidate(characters: Int, wordCount: Int) {
        lock.lock()
        opportunity?.noteVisibleCandidate(characters: characters, wordCount: wordCount)
        lock.unlock()
    }

    static func noteTyped(at time: Date = Date()) {
        lock.lock()
        meter.noteTyped()
        opportunity?.noteTyped(at: time)
        lastActivity = time
        let stillVisible = opportunity != nil
        lock.unlock()
        if !stillVisible { return }
    }

    static func closeIfGhostGone(stillVisible: Bool, at time: Date = Date()) {
        guard !stillVisible else { return }
        closeOpenOpportunity(at: time)
    }

    static func noteAccepted(
        _ text: String,
        kind: LiveOnlineOpportunity.AcceptKind,
        remainderVisible: Bool,
        at time: Date = Date()
    ) {
        if dropIfWiped() { return }
        lock.lock()
        meter.noteAccepted(characters: text.count)
        opportunity?.noteAccepted(text, kind: kind, at: time)
        lastActivity = time
        let ready = remainderVisible ? nil : opportunity
        if !remainderVisible { opportunity = nil }
        lock.unlock()
        guard let ready, ready.didAccept else { return }
        startWatch(ready)
    }

    static func noteDismissed(at time: Date = Date()) {
        lock.lock()
        opportunity?.noteDismissed(at: time)
        lastActivity = time
        lock.unlock()
        closeOpenOpportunity(at: time)
    }

    static func markPrivacyExcluded() {
        lock.lock()
        excluded = true
        meter.reset()
        var completed: [PendingRetainedWatch] = []
        for index in watches.indices {
            watches[index].markPrivacyExcluded()
            if watches[index].isComplete {
                completed.append(watches[index])
            }
        }
        watches.removeAll { $0.isComplete }
        let open = opportunity
        opportunity = nil
        lock.unlock()
        if let open, open.didAccept {
            var watch = PendingRetainedWatch(opportunity: open)
            watch.markPrivacyExcluded()
            emit(watch: &watch)
        } else if let open {
            emitWithoutWatch(open)
        }
        for var watch in completed {
            emit(watch: &watch)
        }
    }

    static func closeOpenGhost(at time: Date = Date()) {
        _ = dropIfWiped()
        closeOpenOpportunity(at: time)
    }

    static func closeSegment(at time: Date = Date()) {
        if dropIfWiped() { return }
        closeOpenOpportunity(at: time)
        let window = currentWindow()
        lock.lock()
        var completed: [PendingRetainedWatch] = []
        for index in watches.indices {
            try? watches[index].closeSegment(window: window)
            if watches[index].isComplete {
                completed.append(watches[index])
            }
        }
        watches.removeAll { $0.isComplete }
        meter.reset()
        lastActivity = time
        lock.unlock()
        for var watch in completed {
            emit(watch: &watch)
        }
    }

    static func observeDueHorizons(now: Date = Date()) {
        if dropIfWiped() { return }
        let window = currentWindow()
        lock.lock()
        var completed: [PendingRetainedWatch] = []
        for index in watches.indices {
            let shown = watches[index].opportunity.shownAt
            if now.timeIntervalSince(shown) >= RetainedSpanWatch.fiveSecondHorizon {
                try? watches[index].observeFiveSeconds(window: window)
            }
            if now.timeIntervalSince(shown) >= RetainedSpanWatch.thirtySecondHorizon {
                try? watches[index].observeThirtySeconds(window: window)
            }
            if now.timeIntervalSince(lastActivity) >= RetainedSpanWatch.idleSegmentSeconds {
                try? watches[index].closeSegment(window: window)
            }
            if watches[index].isComplete {
                completed.append(watches[index])
            }
        }
        watches.removeAll { $0.isComplete }
        lock.unlock()
        for var watch in completed {
            emit(watch: &watch)
        }
    }

    private static func startWatch(_ opportunity: LiveOnlineOpportunity) {
        lock.lock()
        if excluded {
            lock.unlock()
            return
        }
        if watches.count >= RetainedSpanWatch.maximumPendingWatches {
            var oldest = watches.removeFirst()
            oldest.stopObserver()
            lock.unlock()
            emit(watch: &oldest)
            lock.lock()
        }
        watches.append(PendingRetainedWatch(opportunity: opportunity))
        lock.unlock()
        scheduleHorizonChecks()
    }

    private static func closeOpenOpportunity(at time: Date) {
        lock.lock()
        var closing = opportunity
        opportunity = nil
        closing?.settleVisible(at: time)
        lock.unlock()
        guard let closing else { return }
        if closing.didAccept {
            startWatch(closing)
            return
        }
        emitWithoutWatch(closing)
    }

    private static func emitWithoutWatch(_ opportunity: LiveOnlineOpportunity) {
        guard let event = try? opportunity.eventWithoutAcceptedSpan() else { return }
        let diary = LocalOutcomeDiaryEntry(
            id: event.id,
            recordedAt: event.occurredAt,
            outcome: event.outcome,
            acceptedText: "",
            five: event.retentionAt5Seconds,
            thirty: event.retentionAt30Seconds,
            segment: event.retentionAtSegmentClose
        )
        append(event: event, diary: diary)
    }

    private static func emit(watch: inout PendingRetainedWatch) {
        let acceptedText = watch.accepted
        guard let event = try? watch.finishedEvent() else { return }
        let diary = LocalOutcomeDiaryEntry(
            id: event.id,
            recordedAt: event.occurredAt,
            outcome: event.outcome,
            acceptedText: acceptedText,
            five: event.retentionAt5Seconds,
            thirty: event.retentionAt30Seconds,
            segment: event.retentionAtSegmentClose
        )
        append(event: event, diary: diary)
    }

    private static func currentWindow() -> String? {
        lock.lock()
        let provider = contextProvider
        let isExcluded = excluded
        lock.unlock()
        if isExcluded { return nil }
        guard Thread.isMainThread else { return nil }
        return provider?()
    }

    private static func scheduleHorizonChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + RetainedSpanWatch.fiveSecondHorizon) {
            observeDueHorizons()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + RetainedSpanWatch.thirtySecondHorizon) {
            observeDueHorizons()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + RetainedSpanWatch.idleSegmentSeconds) {
            observeDueHorizons()
        }
    }

    private static func dropIfWiped() -> Bool {
        let current = UserDefaults.standard.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        )
        lock.lock()
        defer { lock.unlock() }
        if seenGeneration == nil {
            seenGeneration = current
            return false
        }
        guard seenGeneration != current else { return false }
        seenGeneration = current
        opportunity = nil
        watches = []
        meter.reset()
        excluded = true
        return true
    }

    private static func append(event: TextFreeOnlineEvent, diary: LocalOutcomeDiaryEntry) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = TildeProductProfile.current.supportDirectoryName
        let eventURL = TextFreeOnlineEventFile.url(
            homeDirectory: home,
            supportDirectoryName: support
        )
        let diaryURL = LocalOutcomeDiaryFile.url(
            homeDirectory: home,
            supportDirectoryName: support
        )
        guard let eventLine = try? TextFreeOnlineEvent.encodeJSONL(event) else { return }
        let generation = UserDefaults.standard.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        )
        io.async {
            let live = UserDefaults.standard.integer(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            )
            guard live == generation else { return }
            appendOwnerOnly(eventLine, to: eventURL)
            guard !diary.acceptedText.isEmpty,
                  let diaryLine = try? LocalOutcomeDiaryEntry.encodeJSONL(diary) else { return }
            appendOwnerOnly(diaryLine, to: diaryURL)
        }
    }

    private static func appendOwnerOnly(_ data: Data, to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(
                atPath: url.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            )
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}
