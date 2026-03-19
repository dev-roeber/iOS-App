import Foundation

enum DayListPresentation {
    static func exportSelectionTitle(count: Int) -> String {
        guard count > 0 else {
            return "No export days selected"
        }
        return "\(count) \(count == 1 ? "day" : "days") selected for export"
    }

    static func exportSelectionMessage(count: Int) -> String {
        guard count > 0 else {
            return "Mark days in Export and they will stay highlighted here."
        }
        return "The day list mirrors the current GPX selection so marked days stay easy to spot."
    }

    static func searchEmptyMessage(query: String, exportSelectionCount: Int) -> String {
        let base = "No days match \"\(query)\"."
        guard exportSelectionCount > 0 else {
            return "\(base) Try a broader date fragment."
        }
        return "\(base) \(exportSelectionCount) selected export \(exportSelectionCount == 1 ? "day remains" : "days remain") marked when you clear the search."
    }

    static let exportBadgeTitle = "Export"
    static let exportButtonTitle = "Open Export"
}
