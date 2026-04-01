import Foundation
import LocationHistoryConsumer

/// Filter chips for the day list, combinable with text search.
public enum DayListFilterChip: String, Identifiable, CaseIterable, Equatable {
    case favorites = "favorites"
    case hasVisits = "hasVisits"
    case hasRoutes = "hasRoutes"
    case hasDistance = "hasDistance"
    case exportable = "exportable"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .hasVisits: return "Has Visits"
        case .hasRoutes: return "Has Routes"
        case .hasDistance: return "Has Distance"
        case .exportable: return "Exportable"
        }
    }

    public var systemImage: String {
        switch self {
        case .favorites: return "star.fill"
        case .hasVisits: return "mappin.and.ellipse"
        case .hasRoutes: return "location.north.line"
        case .hasDistance: return "ruler"
        case .exportable: return "square.and.arrow.up"
        }
    }
}

/// Combines active filter chips for the day list.
public struct DayListFilter: Equatable {
    public var activeChips: Set<DayListFilterChip>

    public init(activeChips: Set<DayListFilterChip> = []) {
        self.activeChips = activeChips
    }

    public static let empty = DayListFilter()

    public var isActive: Bool { !activeChips.isEmpty }

    public mutating func toggle(_ chip: DayListFilterChip) {
        if activeChips.contains(chip) {
            activeChips.remove(chip)
        } else {
            activeChips.insert(chip)
        }
    }

    public mutating func clearAll() {
        activeChips.removeAll()
    }

    /// Returns `true` if the given summary passes all active chips.
    /// The `isFavorited` parameter is supplied by the call site (from DayFavoritesStore).
    public func passes(summary: DaySummary, isFavorited: Bool) -> Bool {
        for chip in activeChips {
            switch chip {
            case .favorites:
                if !isFavorited { return false }
            case .hasVisits:
                if summary.visitCount == 0 { return false }
            case .hasRoutes:
                if summary.pathCount == 0 { return false }
            case .hasDistance:
                if summary.totalPathDistanceM <= 0 { return false }
            case .exportable:
                if summary.exportablePathCount == 0 && summary.visitCount == 0 { return false }
            }
        }
        return true
    }
}
