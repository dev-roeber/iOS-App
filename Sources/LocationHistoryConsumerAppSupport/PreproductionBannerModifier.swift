#if canImport(SwiftUI)
import SwiftUI

extension Bundle {
    /// Heuristic for TestFlight builds: TestFlight installs ship with a
    /// `sandboxReceipt` instead of the App-Store receipt. Production App-Store
    /// builds return `false`.
    public var isTestFlightBuild: Bool {
        appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}

extension View {
    /// Pins the pre-production banner above the root content using
    /// `safeAreaInset(edge: .top)` so it never overlaps the Dynamic Island.
    /// Visible only in Debug builds or on TestFlight; production App-Store
    /// builds keep the banner hidden.
    @ViewBuilder
    public func preproductionBanner(isActive: Bool) -> some View {
        #if DEBUG
        let showBanner = isActive
        #else
        let showBanner = isActive && Bundle.main.isTestFlightBuild
        #endif

        if showBanner {
            self.safeAreaInset(edge: .top, spacing: 0) {
                LocalTimelineTestModeBanner()
            }
        } else {
            self
        }
    }
}
#endif
