// AppWeatherPill
//
// Glass-capsule weather indicator analogous to the Live toolbar action labels.
// Three states:
//   * loading — ProgressView + "—" placeholder
//   * snapshot — SF symbol + temperature + condition label
//   * error — red dot + "Wetter unverfügbar" (caller localizes)
//
// Visual treatment matches LH2GPXTheme.LiquidGlass: ultraThinMaterial fill +
// hairline outline, capsule shape. Tap-target is wrapped in a button when a
// callback is provided so the user can dismiss / disable from the Live view.

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
public struct AppWeatherPill: View {

    public let snapshot: WeatherSnapshot?
    public let isError: Bool
    public let errorLabel: String
    public let onTap: (() -> Void)?

    public init(
        snapshot: WeatherSnapshot?,
        isError: Bool = false,
        errorLabel: String = "Wetter unverfügbar",
        onTap: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.isError = isError
        self.errorLabel = errorLabel
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var content: some View {
        HStack(spacing: 6) {
            leadingGlyph
            label
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        if isError {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
        } else if let snapshot {
            Image(systemName: Self.symbolName(for: snapshot.condition))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cyan)
        } else {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.7)
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var label: some View {
        if isError {
            Text(errorLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.red.opacity(0.95))
                .lineLimit(1)
        } else if let snapshot {
            HStack(spacing: 4) {
                Text(Self.formatTemperature(snapshot.temperatureC))
                    .font(.caption.weight(.heavy))
                Text(Self.shorten(snapshot.condition))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            Text("—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityLabel: String {
        if isError { return errorLabel }
        guard let snapshot else { return "Wetter wird geladen" }
        return "\(Self.formatTemperature(snapshot.temperatureC)), \(snapshot.condition)"
    }

    // MARK: - Mapping helpers (internal so the tests can exercise them)

    static func formatTemperature(_ celsius: Double) -> String {
        let rounded = Int(celsius.rounded())
        return "\(rounded)°"
    }

    static func shorten(_ condition: String) -> String {
        if condition.count <= 14 { return condition }
        return String(condition.prefix(13)) + "…"
    }

    /// Maps the human-readable WeatherKit condition string onto an SF Symbol.
    /// Intentionally a small set; unknown values fall through to "cloud" so
    /// we never crash on Apple adding a new condition.
    static func symbolName(for condition: String) -> String {
        let key = condition.lowercased()
        if key.contains("sonn") || key.contains("clear") || key.contains("sun") {
            return "sun.max.fill"
        }
        if key.contains("regen") || key.contains("rain") || key.contains("shower") {
            return "cloud.rain.fill"
        }
        if key.contains("schnee") || key.contains("snow") {
            return "cloud.snow.fill"
        }
        if key.contains("gewitter") || key.contains("thunder") || key.contains("storm") {
            return "cloud.bolt.fill"
        }
        if key.contains("nebel") || key.contains("fog") || key.contains("mist") || key.contains("haze") {
            return "cloud.fog.fill"
        }
        if key.contains("teilweise") || key.contains("partly") {
            return "cloud.sun.fill"
        }
        return "cloud.fill"
    }
}
#endif
