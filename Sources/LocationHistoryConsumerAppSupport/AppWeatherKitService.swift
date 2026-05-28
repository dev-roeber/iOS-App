// AppWeatherKitService
//
// Service-layer for the in-app weather panel. This file deliberately stays
// UI-free: it exposes a protocol + DTO, the iOS WeatherKit-backed
// implementation behind `canImport(WeatherKit)` and a deterministic Linux/
// test stub. The real WeatherKit data path is currently wired into the Live
// weather pill; Day/Overview/Export map "weather prepared" track tinting is
// still a placeholder surface until per-route weather enrichment ships.
//
// WeatherKit setup note:
// - WeatherKit requires the **WeatherKit capability** to be enabled in the
//   Xcode project and matching App Service in App Store Connect.
// - The Apple Developer account must have an active Apple Developer Program
//   membership; the capability is not available on free accounts.
// - There is a free request quota (≈ 500k calls / month / team); the service
//   throws on exhaustion.
// The app target declares the entitlement and Xcode SystemCapabilities entry;
// the matching App ID service + refreshed provisioning profile remain an
// external Apple Developer Portal requirement.

import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

/// Coordinate shim usable on every platform — on Apple we re-export
/// `CLLocationCoordinate2D`, on Linux we provide a value-type stand-in so
/// the provider protocol still compiles for the test stub.
#if canImport(CoreLocation)
public typealias AppWeatherCoordinate = CLLocationCoordinate2D
#else
public struct AppWeatherCoordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
#endif

/// Lightweight DTO returned by every weather provider. Intentionally tiny —
/// future fields (windSpeed, humidity, UVIndex, …) will land in follow-up
/// PRs together with their UI surfaces.
public struct WeatherSnapshot: Sendable, Equatable {
    /// Temperature in degrees Celsius.
    public let temperatureC: Double
    /// Free-form, localised condition label (e.g. "Sonnig", "Bewölkt").
    public let condition: String
    /// Sample timestamp.
    public let timestamp: Date

    public init(temperatureC: Double, condition: String, timestamp: Date) {
        self.temperatureC = temperatureC
        self.condition = condition
        self.timestamp = timestamp
    }
}

/// Protocol every weather provider must conform to. Async-throws so the iOS
/// WeatherKit call can be awaited directly.
public protocol WeatherDataProvider: Sendable {
    func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot
}

/// Errors surfaced to the caller. Stable across providers so call sites can
/// switch on a single enum without leaking WeatherKit internals.
public enum AppWeatherError: Error, Sendable, Equatable {
    case unavailable
    /// WeatherKit-Auth-Fehler ohne gueltige Entitlement-/Provisioning-Kette.
    /// Wird aus `WDSJWTAuthenticatorServiceListener.Errors` Code 1/2 sowie
    /// vergleichbaren JWT-Authentifizierungs-Pfaden klassifiziert. Aufrufer
    /// SOLLEN beim Empfang KEINE Retries oder Backoff einplanen — das
    /// Feature ist clientseitig nicht freigeschaltet, jeder weitere Call
    /// verbraucht Quota ohne Erfolgschance.
    case notProvisioned(String)
    case requestFailed(String)

    /// `true` wenn der Fehler clientseitig dauerhaft ist und Retry-Loops
    /// sinnlos sind.
    public var isPermanent: Bool {
        switch self {
        case .notProvisioned, .unavailable: return true
        case .requestFailed: return false
        }
    }

    public var diagnosticDescription: String {
        switch self {
        case .unavailable:
            return "WeatherKit is unavailable on this platform."
        case let .notProvisioned(message):
            return message.isEmpty ? "WeatherKit not provisioned." : message
        case let .requestFailed(message):
            return message
        }
    }

    public var userFacingGermanTitle: String {
        switch self {
        case .notProvisioned:
            return "Wetter nicht freigeschaltet"
        case .unavailable, .requestFailed:
            return "Wetter unverfügbar"
        }
    }

    public var userFacingGermanDiagnostic: String {
        let hint = "Bitte WeatherKit-Entitlement, Provisioning Profile und Developer-Portal App Services prüfen. App nach Profile-Refresh neu installieren."
        switch self {
        case .unavailable:
            return "\(hint) Diagnose: WeatherKit ist auf dieser Plattform nicht verfügbar."
        case let .notProvisioned(message):
            let head = "WeatherKit lehnt die Authentifizierung ab — die App-ID ist im Apple Developer Portal nicht fuer WeatherKit freigeschaltet, das Provisioning Profile ist veraltet oder das Entitlement fehlt. Automatische Wiederholungsversuche sind deaktiviert, weil sie das Quota verbrauchen wuerden."
            guard !message.isEmpty else { return "\(hint) Diagnose: \(head)"  }
            return "\(hint) Diagnose: \(head) Detail: \(Self.redacted(message))"
        case let .requestFailed(message):
            guard !message.isEmpty else { return hint }
            return "\(hint) Diagnose: \(Self.redacted(message))"
        }
    }

    private static func redacted(_ message: String) -> String {
        let words = message.split(whereSeparator: \.isWhitespace)
        var redactedWords: [String] = []
        var index = words.startIndex

        while index < words.endIndex {
            let word = words[index]
            let lowercased = word.lowercased()
            let normalized = lowercased.trimmingCharacters(in: CharacterSet(charactersIn: ":"))

            if normalized == "authorization" {
                redactedWords.append(String(word))
                let nextIndex = words.index(after: index)
                if nextIndex < words.endIndex,
                   words[nextIndex].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":")) == "bearer" {
                    redactedWords.append(String(words[nextIndex]))
                    let tokenIndex = words.index(after: nextIndex)
                    if tokenIndex < words.endIndex {
                        redactedWords.append("[redacted]")
                        index = words.index(after: tokenIndex)
                    } else {
                        index = tokenIndex
                    }
                } else if nextIndex < words.endIndex {
                    redactedWords.append("[redacted]")
                    index = words.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
            } else if normalized == "bearer" {
                redactedWords.append(String(word))
                let nextIndex = words.index(after: index)
                if nextIndex < words.endIndex {
                    redactedWords.append("[redacted]")
                    index = words.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
            } else if lowercased.hasPrefix("token=") || lowercased.hasPrefix("jwt=") {
                let key = word.prefix { $0 != "=" }
                redactedWords.append("\(key)=[redacted]")
                index = words.index(after: index)
            } else {
                redactedWords.append(String(word))
                index = words.index(after: index)
            }
        }

        return redactedWords.joined(separator: " ")
    }
}

public enum AppWeatherDiagnostics {

    /// Klassifiziert einen WeatherKit-/NSError-Fehler in eine stabile
    /// `AppWeatherError`-Variante. WeatherKit liefert Auth-Probleme als
    /// `WDSJWTAuthenticatorServiceListener.Errors` (Codes 1/2) zurueck;
    /// die kommen auf einem Geraet ohne aktive App-ID-WeatherKit-
    /// Capability bzw. mit veraltetem Provisioning Profile. Wir mappen
    /// das auf `.notProvisioned`, damit Aufrufer keine Retries ausloesen.
    public static func classify(_ error: Error) -> AppWeatherError {
        if let appError = error as? AppWeatherError {
            return appError
        }
        let nsError = error as NSError
        let message = requestFailedMessage(from: error)
        if isNotProvisionedError(domain: nsError.domain, code: nsError.code, debug: message) {
            return .notProvisioned(message)
        }
        return .requestFailed(message)
    }

    /// `true` wenn Domain/Code/Debug-Text auf den WeatherKit-Auth-Fehler
    /// passen, der ohne Entitlement/Portal-Service auftritt.
    /// Erkannt werden:
    ///   - `WDSJWTAuthenticatorServiceListener.Errors` Code 1/2.
    ///   - Domain `com.apple.weatherkit.authservice` (alle Codes).
    ///   - HTTP 401 / 403 aus WeatherKit-Stacks.
    static func isNotProvisionedError(domain: String, code: Int, debug: String) -> Bool {
        let normalisedDomain = domain.lowercased()
        if normalisedDomain.contains("wdsjwtauthenticatorservicelistener")
            || normalisedDomain.contains("weatherkit.authservice")
            || normalisedDomain.contains("weatherdaemon.weatherauthorization") {
            return true
        }
        let normalisedDebug = debug.lowercased()
        if normalisedDebug.contains("wdsjwtauthenticatorservicelistener.errors") {
            // Codes 1+2 zaehlen beide als Auth-Verweigerung; der Listener
            // unterscheidet "kein Token" vs "Token abgelehnt".
            if code == 1 || code == 2 { return true }
            // Wenn der Code in der Domain als Suffix kommt, akzeptieren wir
            // auch das (Apple liefert das Code-Praefix manchmal als Text).
            if normalisedDebug.contains("code=1") || normalisedDebug.contains("code=2") {
                return true
            }
        }
        // HTTP-401/403 aus WeatherKit landet ueblicherweise im Debug-Text.
        if normalisedDebug.contains("weather") && (code == 401 || code == 403) {
            return true
        }
        return false
    }

    public static func requestFailedMessage(from error: Error) -> String {
        if let appError = error as? AppWeatherError {
            return appError.diagnosticDescription
        }
        let nsError = error as NSError
        var parts: [String] = [
            "\(type(of: error))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)"
        ]
        let description = nsError.localizedDescription
        if !description.isEmpty {
            parts.append(description)
        }
        let debugText = String(reflecting: error)
        if debugText != description {
            parts.append(debugText)
        }
        if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !reason.isEmpty {
            parts.append(reason)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("underlying=\(requestFailedMessage(from: underlying))")
        }
        return parts.joined(separator: " | ")
    }
}

// MARK: - Deterministic stub (Linux + tests)

/// Returns a fixed snapshot — useful for previews, snapshot tests and Linux
/// CI where WeatherKit cannot be linked.
public final class StaticWeatherProvider: WeatherDataProvider, @unchecked Sendable {
    private let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    public convenience init() {
        self.init(snapshot: WeatherSnapshot(
            temperatureC: 18.0,
            condition: "Bewölkt",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        ))
    }

    public func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot {
        snapshot
    }
}

// MARK: - Default provider resolution
//
// `defaultProvider` returns the WeatherKit-backed service on iOS where the
// framework can be linked, and falls back to the deterministic stub on Linux/
// macOS/Test builds. Call sites (live tracking view, cache manager) should
// prefer this helper so the Linux test suite stays runnable.

public enum AppWeatherProviderResolver {
    public static var defaultProvider: WeatherDataProvider {
        #if canImport(WeatherKit) && os(iOS)
        if #available(iOS 16.0, *) {
            return WeatherKitService.shared
        }
        return StaticWeatherProvider()
        #else
        return StaticWeatherProvider()
        #endif
    }
}

// MARK: - WeatherKit-backed implementation (iOS only)

#if canImport(WeatherKit) && os(iOS)
import WeatherKit

/// Production WeatherKit implementation. Requires the WeatherKit entitlement
/// on the host app; see file-level note above. Calls the shared
/// `WeatherService` for a single-shot current-conditions request and maps
/// the result onto our compact `WeatherSnapshot` DTO.
@available(iOS 16.0, *)
public final class WeatherKitService: WeatherDataProvider, @unchecked Sendable {
    public static let shared = WeatherKitService()

    public init() {}

    public func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            let tempC = current.temperature.converted(to: .celsius).value
            let condition = current.condition.description
            return WeatherSnapshot(
                temperatureC: tempC,
                condition: condition,
                timestamp: current.date
            )
        } catch {
            // Klassifizieren statt blind als requestFailed durchreichen:
            // `WDSJWTAuthenticatorServiceListener.Errors` (Code 1/2) bedeutet
            // "App-ID nicht fuer WeatherKit freigeschaltet" und ist
            // permanent — Aufrufer SOLLEN keinen Retry/Backoff starten.
            throw AppWeatherDiagnostics.classify(error)
        }
    }
}
#endif
