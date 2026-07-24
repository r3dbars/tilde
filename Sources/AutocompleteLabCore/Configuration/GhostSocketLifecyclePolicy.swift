import Foundation

/// Pure lifecycle decisions for the ghost socket — the unix socket the keyboard
/// talks to. The failure mode these rules prevent: a transient second app
/// instance (e.g. a `--verify` launch) briefly starts, its teardown unlinks the
/// shared socket path, and the keyboard silently demotes to the Apple fallback
/// voice while the primary instance looks perfectly healthy.
public enum GhostSocketLifecyclePolicy {

    /// What a starting server should do with a pre-existing file at the socket path.
    public enum BindAction: Equatable {
        /// Nothing answered a probe connection — a stale file from a dead
        /// process; replace it.
        case replaceStaleSocket
        /// A live server answered the probe — this process is a duplicate and
        /// must not steal the path.
        case leaveLiveSocketAlone
    }

    public static func bindAction(liveServerAnswersProbe: Bool) -> BindAction {
        liveServerAnswersProbe ? .leaveLiveSocketAlone : .replaceStaleSocket
    }

    /// Whether a stopping server may unlink the file at the socket path.
    /// Only the process that bound the *current* file may remove it:
    /// never bound → nothing of ours to clean; file already gone → nothing to
    /// do; file identity changed → another instance rebound and the file is its
    /// live socket, not ours.
    public static func shouldUnlinkOnStop(
        didBindSocket: Bool,
        boundFileID: UInt64?,
        currentFileID: UInt64?
    ) -> Bool {
        guard didBindSocket, let bound = boundFileID, let current = currentFileID else {
            return false
        }
        return bound == current
    }
}
