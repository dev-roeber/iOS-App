#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

@main
struct LH2GPXWidgetBundle: WidgetBundle {
    var body: some Widget {
        LH2GPXHomeWidget()
        TrackingLiveActivityWidget()
    }
}
#endif
