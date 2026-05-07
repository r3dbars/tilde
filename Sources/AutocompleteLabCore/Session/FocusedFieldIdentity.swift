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

public struct FocusedElementFingerprint: Equatable, Sendable {
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
