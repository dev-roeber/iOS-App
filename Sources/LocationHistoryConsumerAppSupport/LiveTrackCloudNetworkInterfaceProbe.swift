import Foundation
#if canImport(Network)
import Network
#endif

/// Best-Effort-Probe der aktuellen Netzwerk-Schnittstelle. Wird vom
/// Auto-Upload-Pfad genutzt, um den Wi-Fi-only-Toggle zu respektieren.
/// Singleton-Lifecycle, weil `NWPathMonitor` einen aktiven Listener
/// halten muss.
///
/// **Hinweis:** `current()` liest den zuletzt beobachteten Pfad.
/// Direkt nach App-Start kann der Status `.unknown` sein, weil der
/// erste Callback des Monitors noch nicht gefeuert hat. Das ist
/// akzeptabel — Auto-Upload skipped dann auf Cellular einfach den
/// nächsten Import-Run nach.
public enum LiveTrackCloudNetworkInterfaceProbe {
    #if canImport(Network)
    private static let monitor: NWPathMonitor = {
        let m = NWPathMonitor()
        m.pathUpdateHandler = { path in
            update(from: path)
        }
        m.start(queue: DispatchQueue(label: "LiveTrackCloudNetworkInterfaceProbe"))
        return m
    }()

    private nonisolated(unsafe) static var lastObserved: LiveTrackCloudNetworkInterface = .unknown
    private static let lock = NSLock()

    private static func update(from path: NWPath) {
        lock.lock(); defer { lock.unlock() }
        if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
            lastObserved = .wifiOrWired
        } else if path.usesInterfaceType(.cellular) {
            lastObserved = .cellular
        } else {
            lastObserved = .unknown
        }
    }
    #endif

    /// Aktueller Netzwerk-Interface-Typ. Triggert den Monitor beim
    /// ersten Aufruf.
    @discardableResult
    public static func current() -> LiveTrackCloudNetworkInterface {
        #if canImport(Network)
        _ = monitor // touch lazy property → startet Monitor falls noch nicht
        lock.lock(); defer { lock.unlock() }
        return lastObserved
        #else
        return .unknown
        #endif
    }
}
