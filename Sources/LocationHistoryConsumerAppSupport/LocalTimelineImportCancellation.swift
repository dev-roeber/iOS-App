import Foundation

/// Cooperative cancellation primitive for the `LocalTimelineStore` import
/// path (Phase-10A P1-A).
///
/// Thread-safe (NSLock-guarded), reference-typed so producer + consumer
/// share the same instance, idempotent, no global state. Callers create
/// one token per import; the importer/writer poll `checkCancellation()`
/// at well-defined points (before stream start, periodically inside the
/// stream loop, before each writer mutation, before finalize). UI calls
/// `cancel()` from any thread.
public final class LocalTimelineImportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled: Bool = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }

    /// Mark cancellation. Idempotent — safe to call multiple times.
    public func cancel() {
        lock.lock()
        _cancelled = true
        lock.unlock()
    }

    /// Throws `LocalTimelineImportCancellationError.cancelled` if `cancel()`
    /// has been called, otherwise returns. Cheap; safe to call inside loops.
    public func checkCancellation() throws {
        if isCancelled {
            throw LocalTimelineImportCancellationError.cancelled
        }
    }
}

/// Error raised by `LocalTimelineImportCancellation.checkCancellation()` and
/// propagated by importer/writer when cancellation is observed.
public enum LocalTimelineImportCancellationError: Error, Equatable {
    case cancelled
}
