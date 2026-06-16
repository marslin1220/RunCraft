#if os(iOS) && canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Activates `WCSession.default` once per process. RunCraft's iPhone app
/// only sends messages — it doesn't need to react to delegate callbacks
/// beyond logging activation/deactivation.
///
/// `@unchecked Sendable`: holds no mutable state beyond registering itself
/// as `WCSession.default`'s delegate once at init.
final class WCSessionActivator: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WCSessionActivator()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            watchConnectivityLogger.error("activation failed: \(String(describing: error), privacy: .public)")
        } else {
            watchConnectivityLogger.log("activation completed: state=\(activationState.rawValue, privacy: .public)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
