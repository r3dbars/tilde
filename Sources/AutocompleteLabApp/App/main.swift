import AppKit

if ProofOnlyAcceptCommand.isRequested(arguments: CommandLine.arguments) {
    exit(ProofOnlyAcceptCommand.run())
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.run()
