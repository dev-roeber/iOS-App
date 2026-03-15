import Foundation

public struct ExportOverview: Equatable {
    public let schemaVersion: String
    public let exportedAt: String
    public let toolVersion: String
    public let inputFormat: String?
    public let mode: String?
    public let splitMode: String?
    public let dayCount: Int
    public let totalVisitCount: Int
    public let totalActivityCount: Int
    public let totalPathCount: Int
    public let statsActivityTypes: [String]
}
