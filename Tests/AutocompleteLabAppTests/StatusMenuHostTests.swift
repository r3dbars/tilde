import Foundation
import Testing

@Suite("Status menu host wiring")
struct StatusMenuHostTests {
    @Test("AppDelegate delegates menu construction and status item updates")
    func appDelegateDelegatesStatusMenuConstruction() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/StatusMenuHost.swift"),
            encoding: .utf8
        )
        let wiring = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/StatusMenuWiring.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("StatusMenuHost(\n        handler: self"))
        #expect(wiring.contains("extension AppDelegate: StatusMenuActionHandling"))
        #expect(wiring.contains("handleStatusMenuAction(_ action: StatusMenuAction)"))
        #expect(!appDelegate.contains("private func configureStatusItem()"))
        #expect(!appDelegate.contains("#selector("))
        #expect(host.contains("developerMenuEnabled"))
        #expect(host.contains("func update("))
        #expect(host.contains("func start(pauseSuggestionsTitle: String)"))
    }
}
