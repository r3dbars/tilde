import Darwin
import Foundation

public enum LabResearchProcessLiveness {
    public static func isAlive(_ processIdentifier: Int32) -> Bool {
        guard processIdentifier > 0 else { return false }
        if processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }
        errno = 0
        if kill(processIdentifier, 0) == 0 { return true }
        return errno == EPERM
    }
}
