import Foundation
#if canImport(Combine)
import Combine
#endif

/// Phase-10A P1-A/B (Weg 2) — UI-Bridge zwischen
/// `LocalTimelineImportController` und SwiftUI/AppShell.
///
/// Hält den letzten beobachteten `LocalTimelineImportProgress`-Snapshot, eine
/// abgeleitete `LocalTimelineImportProgressPresentation` und delegiert
/// Cancel-Anfragen an den aktiven Controller. Pro Import wird via
/// `startNewImport()` ein frischer Controller erzeugt, damit ein vorheriges
/// Cancel-Token nicht in den nächsten Import durchschlägt.
///
/// `@Published` ist auf Linux durch den `CombineCompatibility`-Shim degradiert
/// (kein Observation, aber lesbar). Auf Apple-Plattformen treibt es SwiftUI.
@MainActor
public final class LocalTimelineImportUIState: ObservableObject {
    @Published public private(set) var snapshot: LocalTimelineImportProgress?
    @Published public private(set) var controller: LocalTimelineImportController?

    private var observerHandle: LocalTimelineImportController.ObserverHandle?

    public init() {}

    /// Erzeugt einen frischen Controller für den nächsten Store-Import und
    /// hängt einen Main-Thread-Observer ein. Vorherige Snapshots/Observer
    /// werden verworfen. Liefert den Controller, dessen `progressSink` und
    /// `cancellation` an den Loader weitergereicht werden müssen.
    public func startNewImport() -> LocalTimelineImportController {
        observerHandle?.remove()
        observerHandle = nil
        let controller = LocalTimelineImportController()
        self.controller = controller
        self.snapshot = nil
        observerHandle = controller.addObserver { [weak self] snap in
            // Observer feuert auf Producer-Thread; auf MainActor hoppen.
            Task { @MainActor [weak self] in
                self?.snapshot = snap
            }
        }
        return controller
    }

    /// Synchroner Helfer für Tests/Linux: spielt einen Snapshot direkt ein,
    /// ohne Producer-Thread-Hop. In Production läuft der Pfad ausschließlich
    /// über `startNewImport()` + Observer.
    public func acceptSnapshotForTesting(_ progress: LocalTimelineImportProgress) {
        self.snapshot = progress
    }

    /// Setzt UI-State zurück. Wird von Cleanup-Pfaden (clear/error) gerufen.
    public func reset() {
        observerHandle?.remove()
        observerHandle = nil
        controller = nil
        snapshot = nil
    }

    /// Delegiert an den aktiven Controller. Idempotent.
    public func cancel() {
        controller?.cancel()
    }

    /// Abgeleitete Presentation-Schicht (UI-Strings, kein Standortbezug).
    public var presentation: LocalTimelineImportProgressPresentation? {
        guard let snapshot else { return nil }
        return LocalTimelineImportProgressPresentation(progress: snapshot)
    }

    /// Aktiv genau dann, wenn ein Snapshot in einer nicht-terminalen Phase
    /// vorliegt. UI-Hosts blenden die Progress-View unter dieser Bedingung
    /// ein (zusätzlich zu `session.isLoading`).
    public var isActive: Bool {
        guard let snapshot else { return false }
        switch snapshot.phase {
        case .preparing, .sniffing, .importing, .finalizing:
            return true
        case .idle, .completed, .cancelled, .failed:
            return false
        }
    }

    /// Zusätzlich `idle`: True, sobald irgendein Snapshot geliefert wurde —
    /// inkl. `idle`. UI nutzt das, um die Progress-Card einzublenden, sobald
    /// der Controller den ersten Tick fährt; Counts/Phase-Label sind dann
    /// bereits angezeigt, bevor der Importer den ersten Entry zählt.
    public var hasObservedSnapshot: Bool {
        snapshot != nil
    }
}
