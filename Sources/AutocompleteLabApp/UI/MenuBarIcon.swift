import AppKit
import AutocompleteLabCore

enum MenuBarIconState: Equatable {
    case ready
    case paused
    case needsAttention
}

struct MenuBarIconPresentation: Equatable {
    let state: MenuBarIconState

    init(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport
    ) {
        if !isTrusted || !runtimeReport.allowsSuggestions {
            state = .needsAttention
        } else if suggestionsPaused {
            state = .paused
        } else {
            state = .ready
        }
    }

    var symbolName: String {
        switch state {
        case .ready:
            return "text.cursor"
        case .paused:
            return "pause.circle"
        case .needsAttention:
            return "exclamationmark.triangle"
        }
    }

    var accessibilityDescription: String {
        switch state {
        case .ready:
            return "Autocomplete Lab ready"
        case .paused:
            return "Autocomplete Lab paused"
        case .needsAttention:
            return "Autocomplete Lab needs attention"
        }
    }
}

@MainActor
enum MenuBarIconFactory {
    static func image(for presentation: MenuBarIconPresentation) -> NSImage {
        let image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: presentation.accessibilityDescription
        ) ?? fallbackImage()
        image.isTemplate = true
        return image
    }

    private static func fallbackImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.labelColor.setStroke()
        let cursor = NSBezierPath()
        cursor.lineWidth = 2
        cursor.move(to: NSPoint(x: 8, y: 3))
        cursor.line(to: NSPoint(x: 8, y: 15))
        cursor.stroke()

        let line = NSBezierPath()
        line.lineWidth = 2
        line.move(to: NSPoint(x: 11, y: 9))
        line.line(to: NSPoint(x: 16, y: 9))
        line.stroke()

        image.unlockFocus()
        return image
    }
}
