import Foundation
import LocationHistoryConsumer

/// Train P, Phase 2 — Renders `ExportFormatGuidance.Copy` (Train O) into
/// the field set an export-format card / disclosure footer needs.
///
/// The export sheet shouldn't have to know about copy shape — it asks
/// for `rendered(for:german:)` and lays out four labels:
/// `title`, `primaryUse`, `tools` (with caption prefix), `strengths`.
public enum ExportFormatGuidancePresentation {

    public struct Rendered: Equatable, Sendable {
        /// Short header line — e.g. "GPX guidance" / "GPX-Hilfe".
        public let title: String
        /// One-sentence primary use case copy.
        public let primaryUse: String
        /// Caption-prefixed tools line, e.g.
        /// "Typical tools: Garmin Connect, Komoot, Strava".
        public let tools: String
        /// Strength bullets, each prefixed with a leading "• ".
        public let strengths: [String]

        public init(title: String, primaryUse: String, tools: String, strengths: [String]) {
            self.title = title
            self.primaryUse = primaryUse
            self.tools = tools
            self.strengths = strengths
        }
    }

    public static func rendered(for format: ExportFormat, german: Bool) -> Rendered {
        let copy = ExportFormatGuidance.copy(for: format, german: german)
        return Rendered(
            title: title(for: format, german: german),
            primaryUse: copy.primaryUseCase,
            tools: toolsLine(typicalTools: copy.typicalTools, german: german),
            strengths: copy.strengths.map { "• \($0)" }
        )
    }

    // MARK: - Internals (for direct testing)

    internal static func title(for format: ExportFormat, german: Bool) -> String {
        if german {
            return "\(format.rawValue)-Hilfe"
        }
        return "\(format.rawValue) guidance"
    }

    internal static func toolsLine(typicalTools: String, german: Bool) -> String {
        let prefix = german ? "Typische Tools: " : "Typical tools: "
        return prefix + typicalTools
    }
}
