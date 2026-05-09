import AppKit

if PrivacyExportProofCommand.isRequested(arguments: CommandLine.arguments) {
    exit(PrivacyExportProofCommand.run(arguments: CommandLine.arguments))
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.run()
