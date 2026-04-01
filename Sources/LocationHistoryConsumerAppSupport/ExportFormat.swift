import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public enum ExportFormat: String, Identifiable, CaseIterable {
    case gpx = "GPX"
    case kml = "KML"
    case geoJSON = "GeoJSON"
    case csv = "CSV"

    public static let allCases: [ExportFormat] = [.gpx, .kml, .geoJSON, .csv]

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .gpx:
            return "gpx"
        case .kml:
            return "kml"
        case .geoJSON:
            return "geojson"
        case .csv:
            return "csv"
        }
    }

    public var description: String {
        switch self {
        case .gpx:
            return "GPS Exchange Format – compatible with most navigation and mapping apps."
        case .kml:
            return "Keyhole Markup Language – useful for Google Earth and other map viewers."
        case .geoJSON:
            return "GeoJSON FeatureCollection – useful for browsers, GIS tools, and developer workflows."
        case .csv:
            return "Comma-Separated Values – tabular data compatible with spreadsheet applications."
        }
    }

    public var systemImage: String {
        switch self {
        case .gpx:
            return "location.north.line.fill"
        case .kml:
            return "map.fill"
        case .geoJSON:
            return "curlybraces"
        case .csv:
            return "tablecells"
        }
    }

    #if canImport(UniformTypeIdentifiers)
    public var contentType: UTType {
        switch self {
        case .gpx:
            return .gpx
        case .kml:
            return .kml
        case .geoJSON:
            return .geoJSON
        case .csv:
            return .csv
        }
    }
    #endif
}
