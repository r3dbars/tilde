import AppKit

guard let launchMode = TildeLaunchMode(arguments: CommandLine.arguments) else {
    fputs("Usage: Tilde [--release-proof]\n", stderr)
    exit(2)
}

let app = NSApplication.shared
let delegate = AppDelegate(launchMode: launchMode)

app.delegate = delegate
app.run()
