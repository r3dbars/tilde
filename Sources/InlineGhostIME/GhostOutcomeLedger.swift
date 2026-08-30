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
    private static var contextProvider: (@Sendable () -> RetainedContextSnapshot?)?
    private static var excluded = false
    private static var seenGeneration: Int?
    private static var generationByOpportunityID: [UUID: Int] = [:]
    private static var testingHomeDirectory: URL?
    private static var testingDefaults: UserDefaults?
    private static var idleCloseWorkItem: DispatchWorkItem?
    private static var idleScheduleGeneration: UInt64 = 0

    static func configure(
        contextProvider: @escaping @Sendable () -> RetainedContextSnapshot?
    ) {
        lock.lock()
        self.contextProvider = contextProvider
        lock.unlock()
    }

    static func noteShown(
        sessionIdentifier: String,
        bundleIdentifier: String,
        candidateCharacters: Int,
        candidateWordCount: Int,
        opportunityCharacters: Int,
        precedingCharacter: Character?,
        excluded: Bool,
        variant: String = "champion",
        at time: Date = Date()
    ) {
        _ = dropIfWiped()
        closeOpenOpportunity(at: time)
        let register = ContinuationRegister.from(bundleIdentifier: bundleIdentifier)
        let generation = currentGeneration()
        lock.lock()
        self.excluded = excluded
        guard !excluded else {
            opportunity = nil
            lastActivity = time
            lock.unlock()
            return
        }
        let shown = LiveOnlineOpportunity(
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
            opportunityCharacters: opportunityCharacters
        )
        opportunity = shown
        generationByOpportunityID[shown.id] = generation
        lastActivity = time
        lock.unlock()
        rescheduleIdleCloseIfNeeded()
    }

    static func noteVisibleCandidate(characters: Int, wordCount: Int) {
        if dropIfWiped() { return }
        lock.lock()
        opportunity?.noteVisibleCandidate(characters: characters, wordCount: wordCount)
        lock.unlock()
    }

    static func noteTyped(at time: Date = Date()) {
        if dropIfWiped() { return }
        lock.lock()
        opportunity?.noteTyped(at: time)
        lastActivity = time
        let stillVisible = opportunity != nil
        lock.unlock()
        rescheduleIdleCloseIfNeeded()
        if !stillVisible { return }
    }

    static func closeIfGhostGone(stillVisible: Bool, at time: Date = Date()) {
        if dropIfWiped() { return }
        guard !stillVisible else { return }
        closeOpenOpportunity(at: time)
        rescheduleIdleCloseIfNeeded()
    }

    static func noteAccepted(
        _ text: String,
        kind: LiveOnlineOpportunity.AcceptKind,
        insertionLocationUTF16: Int?,
        remainderVisible: Bool,
        at time: Date = Date()
    ) {
        if dropIfWiped() { return }
        lock.lock()
        opportunity?.noteAccepted(
            text,
            kind: kind,
            insertionLocationUTF16: insertionLocationUTF16,
            at: time
        )
        lastActivity = time
        let ready = remainderVisible ? nil : opportunity
        if !remainderVisible { opportunity = nil }
        lock.unlock()
        guard let ready, ready.didAccept else {
            rescheduleIdleCloseIfNeeded()
            return
        }
        startWatch(ready, at: time)
    }

    static func noteDismissed(at time: Date = Date()) {
        if dropIfWiped() { return }
        lock.lock()
        opportunity?.noteDismissed(at: time)
        lastActivity = time
        lock.unlock()
        closeOpenOpportunity(at: time)
        rescheduleIdleCloseIfNeeded()
    }

    static func markPrivacyExcluded() {
        if dropIfWiped() { return }
        lock.lock()
        excluded = true
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
        rescheduleIdleCloseIfNeeded()
    }

    static func closeOpenGhost(at time: Date = Date()) {
        _ = dropIfWiped()
        closeOpenOpportunity(at: time)
    }

    static func closeSegment(at time: Date = Date()) {
        if dropIfWiped() { return }
        closeOpenOpportunity(at: time)
        let snapshot = currentSnapshot()
        lock.lock()
        var completed: [PendingRetainedWatch] = []
        for index in watches.indices {
            try? watches[index].closeSegment(snapshot: snapshot)
            if watches[index].isComplete {
                completed.append(watches[index])
            }
        }
        watches.removeAll { $0.isComplete }
        lastActivity = time
        lock.unlock()
        for var watch in completed {
            emit(watch: &watch)
        }
        rescheduleIdleCloseIfNeeded()
    }

    static func observeDueHorizons(now: Date = Date()) {
        if dropIfWiped() { return }
        let snapshot = currentSnapshot()
        lock.lock()
        var completed: [PendingRetainedWatch] = []
        for index in watches.indices {
            if watches[index].isFiveSecondDue(at: now) {
                try? watches[index].observeFiveSeconds(snapshot: snapshot)
            }
            if watches[index].isThirtySecondDue(at: now) {
                try? watches[index].observeThirtySeconds(snapshot: snapshot)
            }
            if now.timeIntervalSince(lastActivity) >= RetainedSpanWatch.idleSegmentSeconds {
                try? watches[index].closeSegment(snapshot: snapshot)
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

    private static func startWatch(_ opportunity: LiveOnlineOpportunity, at time: Date) {
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
        watches.append(PendingRetainedWatch(opportunity: opportunity, startedAt: time))
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
            startWatch(closing, at: time)
            return
        }
        emitWithoutWatch(closing)
    }

    private static func emitWithoutWatch(_ opportunity: LiveOnlineOpportunity) {
        guard let generation = takeGeneration(for: opportunity.id) else { return }
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
        append(event: event, diary: diary, generation: generation)
    }

    private static func emit(watch: inout PendingRetainedWatch) {
        guard let generation = takeGeneration(for: watch.opportunity.id) else { return }
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
        append(event: event, diary: diary, generation: generation)
    }

    private static func currentSnapshot() -> RetainedContextSnapshot? {
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
        rescheduleIdleCloseIfNeeded()
    }

    private static func rescheduleIdleCloseIfNeeded() {
        lock.lock()
        idleCloseWorkItem?.cancel()
        idleScheduleGeneration &+= 1
        let generation = idleScheduleGeneration
        guard !watches.isEmpty else {
            idleCloseWorkItem = nil
            lock.unlock()
            return
        }
        let work = DispatchWorkItem {
            handleIdleDeadline(generation: generation)
        }
        idleCloseWorkItem = work
        lock.unlock()
        DispatchQueue.main.asyncAfter(
            deadline: .now() + RetainedSpanWatch.idleSegmentSeconds,
            execute: work
        )
    }

    private static func handleIdleDeadline(generation: UInt64) {
        lock.lock()
        guard generation == idleScheduleGeneration else {
            lock.unlock()
            return
        }
        idleCloseWorkItem = nil
        lock.unlock()
        observeDueHorizons()
    }

    private static func dropIfWiped() -> Bool {
        let current = currentGeneration()
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
        generationByOpportunityID = [:]
        idleCloseWorkItem?.cancel()
        idleCloseWorkItem = nil
        idleScheduleGeneration &+= 1
        excluded = true
        return true
    }

    private static func takeGeneration(for id: UUID) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return generationByOpportunityID.removeValue(forKey: id)
    }

    private static func currentGeneration() -> Int {
        configuredDefaults().integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        )
    }

    private static func configuredDefaults() -> UserDefaults {
        lock.lock()
        defer { lock.unlock() }
        return testingDefaults
            ?? UserDefaults(suiteName: PersonalHistorySettingsContract.keyboardSuiteName)
            ?? .standard
    }

    private static func configuredHomeDirectory() -> URL {
        lock.lock()
        defer { lock.unlock() }
        return testingHomeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
    }

    private static func append(
        event: TextFreeOnlineEvent,
        diary: LocalOutcomeDiaryEntry,
        generation: Int
    ) {
        let home = configuredHomeDirectory()
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
        io.async {
            let permitted = {
                configuredDefaults().integer(
                    forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
                ) == generation
            }
            guard appendOwnerOnly(eventLine, to: eventURL, permitted: permitted) else { return }
            guard !diary.acceptedText.isEmpty,
                  let diaryLine = try? LocalOutcomeDiaryEntry.encodeJSONL(diary) else { return }
            appendOwnerOnly(diaryLine, to: diaryURL, permitted: permitted)
        }
    }

    static func resetForTesting(homeDirectory: URL, defaults: UserDefaults) {
        io.sync {}
        lock.lock()
        opportunity = nil
        watches = []
        lastActivity = .distantPast
        contextProvider = nil
        excluded = false
        seenGeneration = nil
        generationByOpportunityID = [:]
        idleCloseWorkItem?.cancel()
        idleCloseWorkItem = nil
        idleScheduleGeneration = 0
        testingHomeDirectory = homeDirectory
        testingDefaults = defaults
        lock.unlock()
    }

    static func finishTesting() {
        io.sync {}
        lock.lock()
        opportunity = nil
        watches = []
        contextProvider = nil
        excluded = false
        seenGeneration = nil
        generationByOpportunityID = [:]
        idleCloseWorkItem?.cancel()
        idleCloseWorkItem = nil
        idleScheduleGeneration = 0
        testingHomeDirectory = nil
        testingDefaults = nil
        lock.unlock()
    }

    static func drainWritesForTesting() {
        io.sync {}
    }

    static func idleScheduleGenerationForTesting() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return idleScheduleGeneration
    }

    @discardableResult
    static func appendOwnerOnly(
        _ data: Data,
        to url: URL,
        permitted: () -> Bool = { true }
    ) -> Bool {
        let directory = url.deletingLastPathComponent()
        guard !url.lastPathComponent.isEmpty,
              let directoryDescriptor = ownerOnlyDirectoryDescriptor(at: directory) else {
            return false
        }
        defer { close(directoryDescriptor) }
        var directoryInfo = stat()
        guard flock(directoryDescriptor, LOCK_EX) == 0,
              fstat(directoryDescriptor, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == getuid(),
              directoryInfo.st_mode & 0o7777 == 0o700,
              directoryInfo.st_nlink > 0,
              permitted() else { return false }

        let descriptor = openat(
            directoryDescriptor,
            url.lastPathComponent,
            O_WRONLY | O_APPEND | O_CREAT | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC,
            0o600
        )
        guard descriptor >= 0 else { return false }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }

        var info = stat()
        guard fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid(),
              info.st_nlink == 1,
              fchmod(descriptor, 0o600) == 0,
              flock(descriptor, LOCK_EX) == 0,
              fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid(),
              info.st_mode & 0o7777 == 0o600,
              info.st_nlink == 1,
              clearNonblocking(descriptor),
              permitted() else { return false }
        do {
            try handle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }

    private static func ownerOnlyDirectoryDescriptor(at directory: URL) -> Int32? {
        let components = directory.path.split(separator: "/").map(String.init)
        guard directory.isFileURL, !components.isEmpty,
              !components.contains(where: { $0 == "." || $0 == ".." }) else { return nil }

        var parent = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { return nil }
        for (index, component) in components.enumerated() {
            var child = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            var wasMissing = false
            if child < 0, errno == ENOENT {
                wasMissing = true
                guard mkdirat(parent, component, 0o700) == 0 || errno == EEXIST else {
                    close(parent)
                    return nil
                }
                child = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            }
            close(parent)
            guard child >= 0 else { return nil }

            let mustTighten = wasMissing || index == components.count - 1
            var info = stat()
            guard fstat(child, &info) == 0,
                  info.st_mode & S_IFMT == S_IFDIR,
                  (!mustTighten || (info.st_uid == getuid() && fchmod(child, 0o700) == 0)),
                  fstat(child, &info) == 0,
                  info.st_mode & S_IFMT == S_IFDIR,
                  (!mustTighten || (
                      info.st_uid == getuid() && info.st_mode & 0o7777 == 0o700
                  )) else {
                close(child)
                return nil
            }
            parent = child
        }
        return parent
    }

    private static func clearNonblocking(_ descriptor: Int32) -> Bool {
        let flags = fcntl(descriptor, F_GETFL)
        return flags >= 0 && fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0
    }
}
