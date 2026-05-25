import Foundation

#if canImport(CloudKit)
import CloudKit

/// Retry-Wrapper für transiente CloudKit-Fehler.
///
/// Wendet exponentielles Backoff (1s → 2s → 4s …) auf Operationen an,
/// die mit einer als transient eingestuften CloudKit-Fehlerkategorie
/// fehlschlagen. Wenn der Server ein `CKErrorRetryAfterKey` mitliefert
/// wird dieser Wert dem berechneten Backoff vorgezogen.
///
/// Nicht retry-fähig: `unknownItem`, `invalidArguments`, `permissionFailure`,
/// `quotaExceeded`, `notAuthenticated` — diese sind dauerhaft und werden
/// sofort weitergeworfen.
public enum CloudKitRetryPolicy {
    /// Führt `operation` aus und wiederholt sie bei transienten Fehlern
    /// bis zu `maxAttempts` mal. Respektiert `Task.checkCancellation`
    /// zwischen den Versuchen.
    public static func retry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        precondition(maxAttempts >= 1, "maxAttempts must be >= 1")
        var attempt = 0
        while true {
            attempt += 1
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < maxAttempts, isTransient(error) else {
                    throw error
                }
                let delay = backoffSeconds(for: error, attempt: attempt)
                try await sleep(seconds: delay)
            }
        }
    }

    /// Kategorisiert `error` als transient (retry sinnvoll) oder nicht.
    /// Public exposed für Tests; nicht zur Verwendung in Call-Sites.
    public static func isTransient(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == CKErrorDomain || ns.domain == "CKErrorDomain" else {
            return false
        }
        switch ns.code {
        case CKError.networkFailure.rawValue,
             CKError.networkUnavailable.rawValue,
             CKError.requestRateLimited.rawValue,
             CKError.serverResponseLost.rawValue,
             CKError.zoneBusy.rawValue,
             CKError.serviceUnavailable.rawValue:
            return true
        default:
            return false
        }
    }

    /// Berechnet das Backoff für `attempt` (1-basiert). Wenn der Server
    /// einen `CKErrorRetryAfterKey` mitschickt wird dieser bevorzugt
    /// genutzt. Werte werden auf einen sinnvollen Bereich geklemmt.
    static func backoffSeconds(for error: Error, attempt: Int) -> Double {
        let ns = error as NSError
        if let retryAfter = (ns.userInfo["CKErrorRetryAfterKey"] as? NSNumber)?.doubleValue,
           retryAfter > 0 {
            return min(retryAfter, 60)
        }
        // 1, 2, 4, 8 …
        let exponent = max(0, attempt - 1)
        let computed = pow(2.0, Double(exponent))
        return min(computed, 30)
    }

    private static func sleep(seconds: Double) async throws {
        let nanos = UInt64(max(0, seconds) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }
}
#endif
