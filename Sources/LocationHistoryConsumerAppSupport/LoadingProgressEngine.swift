import Foundation
#if canImport(Combine)
import Combine
#endif

/// Drives a fake progress value (`0.0 … 1.0`) for the import / loading phase
/// when the underlying loader does not surface a real progress signal.
///
/// Behaviour:
/// - `start()` jumps to `0.05`, then a timer eases toward `0.90` so the bar
///   keeps moving while the actual decode runs.
/// - `complete()` snaps to `1.0`. Callers should fire this from the success
///   path so the visual "settles" at the bright end before the loading view
///   is dismissed.
/// - `cancel()` halts the timer and resets to `0` — for error paths.
/// - `reset()` is the same as `cancel()` and is exposed for explicit clearing.
///
/// The timer is invalidated in `deinit`, on `cancel/reset/complete`, and via
/// the swift `Task`/Combine machinery is not used — a plain `Timer` keeps the
/// engine deterministically testable.
@MainActor
public final class LoadingProgressEngine: ObservableObject {
    @Published public private(set) var progress: Double = 0.0
    /// Coarse pipeline phase reported by `AppContentLoader.loadImportedContent`
    /// via its `onPhase` callback. `nil` until the first phase fires; resets
    /// to `nil` on `cancel()` and `complete()`. UI surfaces this as a label
    /// next to the spinner so users see "Reading…" → "Parsing…" → "Building…"
    /// instead of a generic spinner during multi-second large imports.
    @Published public private(set) var phase: ImportPhase?

    private var timer: Timer?
    /// Maximum value the timer-driven phase will approach. `complete()` is the
    /// only path that pushes past this.
    private let softCeiling: Double = 0.90
    /// How fast the eased curve closes the remaining gap to `softCeiling` per
    /// tick. Larger = faster ramp at start, slower trail-off near the ceiling.
    private let easingFactor: Double = 0.06
    private let tickInterval: TimeInterval = 0.10

    public init() {}

    deinit {
        timer?.invalidate()
        timer = nil
    }

    /// Begin the eased ramp. Idempotent — calling `start()` while already
    /// running keeps the existing curve and does not reset progress.
    public func start() {
        guard timer == nil else { return }
        if progress < 0.05 {
            progress = 0.05
        }
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Records the current pipeline phase. Idempotent for the same value.
    public func setPhase(_ next: ImportPhase) {
        guard phase != next else { return }
        phase = next
    }

    /// Snap to `1.0` and stop the timer. Safe to call multiple times.
    public func complete() {
        timer?.invalidate()
        timer = nil
        progress = 1.0
        phase = nil
    }

    /// Stop the timer and zero the value. Use for error / cancellation paths.
    public func cancel() {
        timer?.invalidate()
        timer = nil
        progress = 0.0
        phase = nil
    }

    public func reset() { cancel() }

    private func tick() {
        let remaining = softCeiling - progress
        if remaining <= 0.001 {
            // Hold steady at the soft ceiling until `complete()` is called.
            progress = softCeiling
            return
        }
        progress = min(softCeiling, progress + remaining * easingFactor)
    }
}
