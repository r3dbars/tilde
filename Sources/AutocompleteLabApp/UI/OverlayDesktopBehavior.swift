import AppKit

enum OverlayDesktopBehavior {
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary
    ]

    static let traceDescription = "can-join-all-spaces+fullscreen-auxiliary"
}
