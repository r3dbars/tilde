import CoreGraphics
import Foundation

public struct FocusedFieldIdentity: Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let processIdentifier: Int32
    public let elementIdentifier: Int

    public init(
        bundleIdentifier: String,
        processIdentifier: Int32,
        elementIdentifier: Int
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.elementIdentifier = elementIdentifier
    }

    public var traceDescription: String {
        "\(bundleIdentifier)|pid:\(processIdentifier)|element:\(elementIdentifier)"
    }
}

public struct FocusedElementFingerprint: Equatable, Hashable, Sendable {
    public let identifier: String?
    public let title: String?
    public let description: String?
    public let help: String?
    public let placeholder: String?
    public let windowTitle: String?

    public init(
        identifier: String? = nil,
        title: String? = nil,
        description: String? = nil,
        help: String? = nil,
        placeholder: String? = nil,
        windowTitle: String? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.help = help
        self.placeholder = placeholder
        self.windowTitle = windowTitle
    }

    public var searchableText: String {
        [
            identifier,
            title,
            description,
            help,
            placeholder,
            windowTitle
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
    }
}

public struct RoundedFocusedRect: Equatable, Hashable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.init(
            x: Int(rect.origin.x.rounded()),
            y: Int(rect.origin.y.rounded()),
            width: Int(rect.width.rounded()),
            height: Int(rect.height.rounded())
        )
    }
}

public struct FocusedTextRevision: Equatable, Hashable, Sendable {
    public let textBeforeCursorLength: Int
    public let textAfterCursorLength: Int
    public let textBeforeCursorHash: UInt64
    public let textAfterCursorHash: UInt64

    public init(
        textBeforeCursorLength: Int,
        textAfterCursorLength: Int,
        textBeforeCursorHash: UInt64,
        textAfterCursorHash: UInt64
    ) {
        self.textBeforeCursorLength = max(0, textBeforeCursorLength)
        self.textAfterCursorLength = max(0, textAfterCursorLength)
        self.textBeforeCursorHash = textBeforeCursorHash
        self.textAfterCursorHash = textAfterCursorHash
    }

    public init(textBeforeCursor: String, textAfterCursor: String) {
        self.init(
            textBeforeCursorLength: textBeforeCursor.count,
            textAfterCursorLength: textAfterCursor.count,
            textBeforeCursorHash: Self.stableHash(textBeforeCursor),
            textAfterCursorHash: Self.stableHash(textAfterCursor)
        )
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

public struct FocusedTargetFingerprint: Equatable, Hashable, Sendable {
    public let role: String?
    public let subrole: String?
    public let elementFingerprint: FocusedElementFingerprint
    public let elementBounds: RoundedFocusedRect?
    public let windowBounds: RoundedFocusedRect?
    public let caretBounds: RoundedFocusedRect?
    public let surroundingTextRevision: FocusedTextRevision?

    public init(
        role: String?,
        subrole: String?,
        elementFingerprint: FocusedElementFingerprint,
        elementBounds: RoundedFocusedRect?,
        windowBounds: RoundedFocusedRect?,
        caretBounds: RoundedFocusedRect?,
        surroundingTextRevision: FocusedTextRevision?
    ) {
        self.role = Self.normalized(role)
        self.subrole = Self.normalized(subrole)
        self.elementFingerprint = Self.normalized(elementFingerprint)
        self.elementBounds = elementBounds
        self.windowBounds = windowBounds
        self.caretBounds = caretBounds
        self.surroundingTextRevision = surroundingTextRevision
    }

    public init(
        role: String?,
        subrole: String?,
        elementFingerprint: FocusedElementFingerprint,
        elementRect: CGRect?,
        windowRect: CGRect?,
        caretRect: CGRect?,
        textBeforeCursor: String,
        textAfterCursor: String
    ) {
        self.init(
            role: role,
            subrole: subrole,
            elementFingerprint: elementFingerprint,
            elementBounds: elementRect.map(RoundedFocusedRect.init),
            windowBounds: windowRect.map(RoundedFocusedRect.init),
            caretBounds: caretRect.map(RoundedFocusedRect.init),
            surroundingTextRevision: FocusedTextRevision(
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
            )
        )
    }

    public func matches(_ current: FocusedTargetFingerprint) -> Bool {
        guard role == current.role,
              subrole == current.subrole,
              elementFingerprint == current.elementFingerprint,
              elementBounds == current.elementBounds,
              windowBounds == current.windowBounds else {
            return false
        }

        if let caretBounds, caretBounds != current.caretBounds {
            return false
        }

        if let surroundingTextRevision,
           surroundingTextRevision != current.surroundingTextRevision {
            return false
        }

        return true
    }

    public var postInsertionScope: FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: role,
            subrole: subrole,
            elementFingerprint: elementFingerprint,
            elementBounds: elementBounds,
            windowBounds: windowBounds,
            caretBounds: nil,
            surroundingTextRevision: nil
        )
    }

    public func advancingTextRevision(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: role,
            subrole: subrole,
            elementFingerprint: elementFingerprint,
            elementBounds: elementBounds,
            windowBounds: windowBounds,
            caretBounds: nil,
            surroundingTextRevision: FocusedTextRevision(
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
            )
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func normalized(_ fingerprint: FocusedElementFingerprint) -> FocusedElementFingerprint {
        FocusedElementFingerprint(
            identifier: normalized(fingerprint.identifier),
            title: normalized(fingerprint.title),
            description: normalized(fingerprint.description),
            help: normalized(fingerprint.help),
            placeholder: normalized(fingerprint.placeholder),
            windowTitle: normalized(fingerprint.windowTitle)
        )
    }
}

public struct FocusedFieldIdentityInput: Equatable, Sendable {
    public let elementIdentifier: Int
    public let role: String?
    public let subrole: String?
    public let fingerprint: FocusedElementFingerprint
    public let elementRect: CGRect?
    public let windowRect: CGRect?

    public init(
        elementIdentifier: Int,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        elementRect: CGRect?,
        windowRect: CGRect?
    ) {
        self.elementIdentifier = elementIdentifier
        self.role = role
        self.subrole = subrole
        self.fingerprint = fingerprint
        self.elementRect = elementRect
        self.windowRect = windowRect
    }
}

public struct FocusedTextSnapshot: Equatable, Sendable {
    public let fieldIdentity: FocusedFieldIdentity
    public let textBeforeCursor: String
    public let textAfterCursor: String

    public init(
        fieldIdentity: FocusedFieldIdentity,
        textBeforeCursor: String,
        textAfterCursor: String
    ) {
        self.fieldIdentity = fieldIdentity
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
    }
}

public struct FocusedFieldIdentityPolicy: Sendable {
    public init() {}

    public func identity(
        bundleIdentifier: String,
        processIdentifier: Int32,
        mode: FocusedFieldIdentityMode,
        input: FocusedFieldIdentityInput
    ) -> FocusedFieldIdentity {
        let elementIdentifier: Int

        switch mode {
        case .accessibilityElement:
            elementIdentifier = input.elementIdentifier
        case .stableBounds:
            elementIdentifier = stableBoundsIdentifier(input: input)
        }

        return FocusedFieldIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            elementIdentifier: elementIdentifier
        )
    }

    private func stableBoundsIdentifier(input: FocusedFieldIdentityInput) -> Int {
        var hasher = Hasher()
        hasher.combine(input.role ?? "unknown")
        hasher.combine(input.subrole ?? "none")
        combineStableFingerprint(input.fingerprint, into: &hasher)
        combineRoundedRect(input.elementRect, into: &hasher)
        combineRoundedRect(input.windowRect, into: &hasher)
        return hasher.finalize()
    }

    private func combineStableFingerprint(
        _ fingerprint: FocusedElementFingerprint,
        into hasher: inout Hasher
    ) {
        combineStableFingerprintValue(fingerprint.identifier, label: "identifier", into: &hasher)
        combineStableFingerprintValue(fingerprint.title, label: "title", into: &hasher)
        combineStableFingerprintValue(fingerprint.description, label: "description", into: &hasher)
        combineStableFingerprintValue(fingerprint.help, label: "help", into: &hasher)
        combineStableFingerprintValue(fingerprint.placeholder, label: "placeholder", into: &hasher)
        combineStableFingerprintValue(fingerprint.windowTitle, label: "windowTitle", into: &hasher)
    }

    private func combineStableFingerprintValue(
        _ value: String?,
        label: String,
        into hasher: inout Hasher
    ) {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalized, !normalized.isEmpty else {
            hasher.combine("\(label):missing")
            return
        }

        hasher.combine(label)
        hasher.combine(normalized)
    }

    private func combineRoundedRect(_ rect: CGRect?, into hasher: inout Hasher) {
        guard let rect else {
            hasher.combine("missing")
            return
        }

        hasher.combine(Int(rect.origin.x.rounded()))
        hasher.combine(Int(rect.origin.y.rounded()))
        hasher.combine(Int(rect.width.rounded()))
        hasher.combine(Int(rect.height.rounded()))
    }
}
