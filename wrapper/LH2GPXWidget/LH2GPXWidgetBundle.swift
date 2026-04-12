#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
@main
struct LH2GPXWidgetBundle: WidgetBundle {
    var body: some Widget {
        LH2GPXHomeWidget()
        TrackingLiveActivityWidget()
    }
}
#endif
