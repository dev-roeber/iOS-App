import Foundation
import LocationHistoryConsumer

/// Train O, Phase 2 — Foundation-only DE/EN guidance copy for the
/// five `ExportFormat` cases. The existing single-line `.description`
/// on `ExportFormat` stays untouched and remains the canonical
/// short-form string for selection-row labels; this helper provides
/// a richer per-format explanation that the export sheet can surface
/// for users who need more context.
///
/// **No format-default change.** This is presentation copy only; the
/// builder output is byte-identical to Build 179.
public enum ExportFormatGuidance {

    public struct Copy: Equatable, Sendable {
        /// One-sentence primary use case ("GPS exchange between
        /// navigation apps"). User-facing.
        public let primaryUseCase: String
        /// Typical consumer apps for the format ("Google Earth,
        /// Apple Maps"). User-facing.
        public let typicalTools: String
        /// Two to three short strengths (bulleted in UI).
        public let strengths: [String]

        public init(primaryUseCase: String, typicalTools: String, strengths: [String]) {
            self.primaryUseCase = primaryUseCase
            self.typicalTools = typicalTools
            self.strengths = strengths
        }
    }

    /// Returns the guidance copy for `format` in either German
    /// (`german == true`) or English. Each format has a static copy
    /// pair — no runtime data, no coordinates.
    public static func copy(for format: ExportFormat, german: Bool) -> Copy {
        switch (format, german) {

        // MARK: GPX
        case (.gpx, false):
            return Copy(
                primaryUseCase: "Navigation and route exchange between GPS-aware apps.",
                typicalTools: "Garmin Connect, Komoot, Strava, GPSies viewers.",
                strengths: [
                    "Standardised by the GPS community.",
                    "Preserves per-point timestamps when available.",
                    "Lossless re-import in most navigation apps.",
                ]
            )
        case (.gpx, true):
            return Copy(
                primaryUseCase: "Navigation und Routenaustausch zwischen GPS-Apps.",
                typicalTools: "Garmin Connect, Komoot, Strava, GPSies-Viewer.",
                strengths: [
                    "GPS-Community-Standard.",
                    "Behält Punkt-Zeitstempel bei, wenn vorhanden.",
                    "Verlustfreier Re-Import in den meisten Navi-Apps.",
                ]
            )

        // MARK: KMZ
        case (.kmz, false):
            return Copy(
                primaryUseCase: "Map viewing in Google Earth and similar map apps.",
                typicalTools: "Google Earth (Pro, Web, Mobile), Apple Maps.",
                strengths: [
                    "Smaller file size — KML payload is zipped.",
                    "Opens with a double-click on Google Earth.",
                    "Carries the same data as a plain KML.",
                ]
            )
        case (.kmz, true):
            return Copy(
                primaryUseCase: "Karten-Ansicht in Google Earth und ähnlichen Karten-Apps.",
                typicalTools: "Google Earth (Pro, Web, Mobil), Apple Karten.",
                strengths: [
                    "Kleinere Datei – KML-Inhalt ist gezippt.",
                    "Öffnet sich per Doppelklick in Google Earth.",
                    "Gleicher Inhalt wie eine reine KML.",
                ]
            )

        // MARK: KML
        case (.kml, false):
            return Copy(
                primaryUseCase: "Map viewing when a text-readable file is needed.",
                typicalTools: "Google Earth, QGIS, custom map viewers.",
                strengths: [
                    "Plain XML — readable and diffable.",
                    "Widely supported across map tooling.",
                    "Easy to edit by hand for small fixes.",
                ]
            )
        case (.kml, true):
            return Copy(
                primaryUseCase: "Karten-Ansicht, wenn eine textlesbare Datei nötig ist.",
                typicalTools: "Google Earth, QGIS, eigene Karten-Viewer.",
                strengths: [
                    "Reines XML – lesbar und diff-bar.",
                    "Breit unterstützt in Karten-Tools.",
                    "Bei Bedarf von Hand korrigierbar.",
                ]
            )

        // MARK: GeoJSON
        case (.geoJSON, false):
            return Copy(
                primaryUseCase: "GIS and developer workflows, web map rendering.",
                typicalTools: "QGIS, Leaflet, Mapbox GL JS, geojson.io.",
                strengths: [
                    "First-class in modern GIS tools and web maps.",
                    "Standard JSON — easy to script against.",
                    "Renders directly in geojson.io for quick checks.",
                ]
            )
        case (.geoJSON, true):
            return Copy(
                primaryUseCase: "GIS- und Entwickler-Workflows, Web-Karten.",
                typicalTools: "QGIS, Leaflet, Mapbox GL JS, geojson.io.",
                strengths: [
                    "First-Class-Format in modernen GIS-Tools und Web-Karten.",
                    "Standard-JSON – einfach skriptbar.",
                    "Lässt sich direkt in geojson.io prüfen.",
                ]
            )

        // MARK: CSV
        case (.csv, false):
            return Copy(
                primaryUseCase: "Spreadsheet analysis and tabular reporting.",
                typicalTools: "Numbers, Excel, Google Sheets, pandas.",
                strengths: [
                    "Opens in every spreadsheet program.",
                    "One row per visit / activity / route segment.",
                    "Ideal for quick sorting and pivot tables.",
                ]
            )
        case (.csv, true):
            return Copy(
                primaryUseCase: "Tabellen-Analyse und tabellarische Berichte.",
                typicalTools: "Numbers, Excel, Google Sheets, pandas.",
                strengths: [
                    "Öffnet sich in jedem Tabellenprogramm.",
                    "Eine Zeile pro Besuch / Aktivität / Route.",
                    "Ideal für schnelle Sortierung und Pivot-Tabellen.",
                ]
            )
        }
    }
}
