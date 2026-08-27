import Darwin
import Dispatch
import Foundation

@main
struct TildeResearchCLI {
    static func main() async {
        do {
            let arguments = try CLIArguments(Array(CommandLine.arguments.dropFirst()))
            if arguments.command == nil || arguments.hasFlag("help") {
                print(ResearchCoordinator.help(for: arguments.command))
                return
            }

            let operation = Task {
                try await ResearchCoordinator.execute(arguments)
            }
            let signals = ResearchSignalController {
                operation.cancel()
            }
            signals.start()
            defer { signals.stop() }
            do {
                try await operation.value
            } catch is CancellationError {
                ResearchConsole.error(
                    "Interrupted safely. Completed work is checkpointed; rerun the same command to resume."
                )
                Darwin.exit(130)
            }
        } catch {
            ResearchConsole.error(error.localizedDescription)
            Darwin.exit(1)
        }
    }
}

final class ResearchSignalController: @unchecked Sendable {
    private let handler: @Sendable () -> Void
    private var sources: [DispatchSourceSignal] = []

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func start() {
        for signalValue in [SIGINT, SIGTERM] {
            Darwin.signal(signalValue, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalValue, queue: .global())
            source.setEventHandler(handler: handler)
            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        for source in sources { source.cancel() }
        sources.removeAll()
    }
}

enum ResearchConsole {
    static func line(_ value: String = "") {
        FileHandle.standardOutput.write(Data((value + "\n").utf8))
    }

    static func error(_ value: String) {
        FileHandle.standardError.write(Data(("tilde-research: " + value + "\n").utf8))
    }
}
