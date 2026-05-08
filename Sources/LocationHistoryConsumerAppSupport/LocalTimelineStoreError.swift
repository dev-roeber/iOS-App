import Foundation

/// Errors raised by the Phase-1 LocalTimelineStore SQLite spike.
///
/// This is a research/spike type. The store is **not** wired into any
/// production app flow. The error cases below cover only what the spike
/// surface needs (open / prepare / step / bind / FK enforcement).
public enum LocalTimelineStoreError: Error, Equatable, CustomStringConvertible {
    case openFailed(path: String, code: Int32, message: String)
    case execFailed(sql: String, code: Int32, message: String)
    case prepareFailed(sql: String, code: Int32, message: String)
    case stepFailed(code: Int32, message: String)
    case bindFailed(parameter: String, code: Int32)
    case foreignKeyViolation
    case notOpen

    public var description: String {
        switch self {
        case let .openFailed(path, code, message):
            return "openFailed(path: \(path), code: \(code), message: \(message))"
        case let .execFailed(sql, code, message):
            return "execFailed(sql: \(sql), code: \(code), message: \(message))"
        case let .prepareFailed(sql, code, message):
            return "prepareFailed(sql: \(sql), code: \(code), message: \(message))"
        case let .stepFailed(code, message):
            return "stepFailed(code: \(code), message: \(message))"
        case let .bindFailed(parameter, code):
            return "bindFailed(parameter: \(parameter), code: \(code))"
        case .foreignKeyViolation:
            return "foreignKeyViolation"
        case .notOpen:
            return "notOpen"
        }
    }
}
