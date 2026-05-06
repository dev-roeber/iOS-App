import Foundation

enum HeatmapMode: String, CaseIterable, Identifiable {
    case route
    case density

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .route: return "Routes"
        case .density: return "Density"
        }
    }
}
