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
        var hasher = StableFieldIdentityHasher()
        hasher.combine("role", normalizedStableValue(input.role))
        hasher.combine("subrole", normalizedStableValue(input.subrole))
        combineStableFingerprint(input.fingerprint, into: &hasher)
        combineRoundedRect(input.elementRect, label: "elementRect", into: &hasher)
        combineRoundedRect(input.windowRect, label: "windowRect", into: &hasher)
        return hasher.finalize()
    }

    private func combineStableFingerprint(
        _ fingerprint: FocusedElementFingerprint,
        into hasher: inout StableFieldIdentityHasher
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
        into hasher: inout StableFieldIdentityHasher
    ) {
        hasher.combine(label, normalizedStableValue(value))
    }

    private func combineRoundedRect(
        _ rect: CGRect?,
        label: String,
        into hasher: inout StableFieldIdentityHasher
    ) {
        guard let rect else {
            hasher.combine(label, "missing")
            return
        }

        hasher.combine(label, "x", Int(rect.origin.x.rounded()))
        hasher.combine(label, "y", Int(rect.origin.y.rounded()))
        hasher.combine(label, "width", Int(rect.width.rounded()))
        hasher.combine(label, "height", Int(rect.height.rounded()))
    }

    private func normalizedStableValue(_ value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalized, !normalized.isEmpty else {
            return "missing"
        }

        return normalized
    }
}

private struct StableFieldIdentityHasher {
    private static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let prime: UInt64 = 1_099_511_628_211
    private static let positiveMask: UInt64 = 0x7fff_ffff_ffff_ffff

    private var value = offsetBasis

    mutating func combine(_ parts: CustomStringConvertible...) {
        for part in parts {
            update(String(describing: part))
            update(byte: 0xff)
        }
        update(byte: 0xfe)
    }

    func finalize() -> Int {
        Int(value & Self.positiveMask)
    }

    private mutating func update(_ string: String) {
        for byte in string.utf8 {
            update(byte: byte)
        }
    }

    private mutating func update(byte: UInt8) {
        value ^= UInt64(byte)
        value = value &* Self.prime
    }
}
