@preconcurrency import Foundation

/// Service-/Presentation-Layer für den Store-Importpfad (Phase-10A P1-A/B).
///
/// Bündelt die drei Bausteine, die Caller (UI/Tests) brauchen, damit sie
/// nicht jeden Hook einzeln verdrahten müssen:
///   * `cancellation` — Cooperative-Cancel-Token, das der Caller an
///     `AppContentLoader.loadImportedContentEnvelope(..., importCancellation:)`
///     weiterreicht.
///   * `progressSink` — `@Sendable` Callback, den der Caller an
///     `AppContentLoader.loadImportedContentEnvelope(..., importProgress:)`
///     weitergibt; der Sink schreibt jeden empfangenen Snapshot in den
///     thread-safen internen Zustand.
///   * `latestProgress` — letzter beobachteter Snapshot. UI/Tests können
///     diesen Wert lesen, um den aktuellen Fortschritt darzustellen.
///   * Optionale Observer-Registrierung, damit reaktive UIs auf jeden
///     neuen Snapshot reagieren können, ohne pollen zu müssen. Observer
///     werden auf dem Producer-Thread aufgerufen — UIs müssen ggf. auf den
///     Main-Thread hoppen.
///
/// Foundation-only, Linux-testbar, keine SwiftUI/ObservableObject-Bindung.
/// Eine SwiftUI-Anbindung ist als Folgeschritt dokumentiert — siehe
/// `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 (P1-A/B).
public final class LocalTimelineImportController: @unchecked Sendable {

    public typealias Observer = @Sendable (LocalTimelineImportProgress) -> Void

    private let lock = NSLock()
    private var _latest: LocalTimelineImportProgress?
    private var observers: [UUID: Observer] = [:]

    public let cancellation: LocalTimelineImportCancellation

    public init(cancellation: LocalTimelineImportCancellation = .init()) {
        self.cancellation = cancellation
    }

    /// Fordert kooperativ den Abbruch des laufenden Imports an.
    /// Idempotent. Der Importer rollt die offene Transaktion zurück und
    /// wirft `LocalTimelineImportCancellationError.cancelled`; der Caller
    /// erhält im AppFlow-Pfad `EnvelopeImportOutcome.failure(...)` mit dem
    /// neuen `AppContentLoaderError.importCancelled`-Titel.
    public func cancel() {
        cancellation.cancel()
    }

    public var isCancelled: Bool { cancellation.isCancelled }

    public var latestProgress: LocalTimelineImportProgress? {
        lock.lock()
        defer { lock.unlock() }
        return _latest
    }

    /// Übergibt diesen Sink als `importProgress:` an den Loader. Snapshots
    /// werden im Controller gespeichert und an alle registrierten Observer
    /// weitergereicht.
    public var progressSink: LocalTimelineImportProgressSink {
        return { [weak self] snapshot in
            guard let self else { return }
            self.lock.lock()
            self._latest = snapshot
            let observers = self.observers
            self.lock.unlock()
            for observer in observers.values {
                observer(snapshot)
            }
        }
    }

    /// Registriert einen Observer und gibt ein Cancel-Handle zurück, mit
    /// dem die Registrierung wieder entfernt werden kann.
    @discardableResult
    public func addObserver(_ observer: @escaping Observer) -> ObserverHandle {
        let token = UUID()
        lock.lock()
        observers[token] = observer
        lock.unlock()
        return ObserverHandle { [weak self] in
            self?.lock.lock()
            self?.observers.removeValue(forKey: token)
            self?.lock.unlock()
        }
    }

    public final class ObserverHandle: @unchecked Sendable {
        private let unregister: @Sendable () -> Void
        private var fired = false
        private let lock = NSLock()
        init(unregister: @escaping @Sendable () -> Void) {
            self.unregister = unregister
        }
        public func remove() {
            lock.lock()
            let alreadyFired = fired
            fired = true
            lock.unlock()
            guard !alreadyFired else { return }
            unregister()
        }
        deinit { remove() }
    }
}
