import AppKit

guard let invocation = TildeInvocation(arguments: CommandLine.arguments) else {
    fputs("Usage: Tilde [--release-proof|--personal-brain-status-json]\n", stderr)
    exit(2)
}

switch invocation {
case .personalBrainStatusJSON:
    switch PersonalBrainStatusCommand().execute() {
    case let .output(json):
        FileHandle.standardOutput.write(Data("\(json)\n".utf8))
        exit(0)
    case let .failure(reason):
        FileHandle.standardOutput.write(Data("\(reason)\n".utf8))
        exit(1)
    }
case let .application(launchMode):
    let app = NSApplication.shared
    let delegate = AppDelegate(launchMode: launchMode)

    app.delegate = delegate
    app.run()
}
