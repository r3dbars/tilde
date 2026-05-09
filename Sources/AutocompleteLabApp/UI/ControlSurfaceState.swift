import Foundation

struct ControlPauseState: Equatable {
    let isPaused: Bool
    let pausedUntil: Date?
    let now: Date

    init(isPaused: Bool, pausedUntil: Date?, now: Date = Date()) {
        self.isPaused = isPaused
        self.pausedUntil = isPaused ? pausedUntil : nil
        self.now = now
    }

    var statusName: String {
        isPaused ? "paused" : "running"
    }

    var statusText: String {
        guard isPaused else {
            return "Global pause: off"
        }

        guard let timeText else {
            return "Global pause: on"
        }

        return "Global pause: until \(timeText)"
    }

    var settingsSummaryText: String {
        guard isPaused else {
            return "Suggestions: ready"
        }

        guard let timeText else {
            return "Suggestions: paused"
        }

        return "Suggestions: paused until \(timeText)"
    }

    var settingsDetailText: String {
        guard isPaused else {
            return "Global suggestions are on. You can still pause one app or one field."
        }

        guard let timeText else {
            return "Global suggestions are paused until you resume them."
        }

        return "Global suggestions are paused until \(timeText). App and field pauses stay separate."
    }

    var menuPausedTitle: String {
        guard isPaused else {
            return "Paused"
        }

        guard let timeText else {
            return "Paused"
        }

        return "Paused until \(timeText)"
    }

    var toggleTitle: String {
        isPaused ? "Resume Suggestions" : "Pause Suggestions"
    }

    var shouldEnableTimedPauseButtons: Bool {
        !isPaused
    }

    private var timeText: String? {
        guard let pausedUntil,
              pausedUntil > now else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: pausedUntil)
    }
}
