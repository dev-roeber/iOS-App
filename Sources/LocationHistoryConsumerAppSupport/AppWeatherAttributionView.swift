// AppWeatherAttributionView
//
// Apple WeatherKit data **must** be displayed alongside an attribution to
// Apple Weather (Apple Developer Program License Agreement). See:
//   https://weatherkit.apple.com/legal-attribution.html
//
// Apple ships a branded asset, but we cannot vendor a binary asset in this
// pure SwiftPM package today. We render the SF Symbol fallback (`apple.logo`
// + text label) which is acceptable per Apple's documentation when the
// branded asset is not bundled. Once the iOS host app embeds the official
// asset catalog entry, the host app can swap in `Image("AppleWeatherLogo")`.

#if canImport(SwiftUI)
import SwiftUI

public struct AppWeatherAttributionView: View {
    public let label: String
    public let legalURLString: String

    public init(
        label: String = "Wetter",
        legalURLString: String = "https://weatherkit.apple.com/legal-attribution.html"
    ) {
        self.label = label
        self.legalURLString = legalURLString
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "apple.logo")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            link
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Weather Attribution")
    }

    @ViewBuilder
    private var link: some View {
        if let url = URL(string: legalURLString) {
            Link(label, destination: url)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
#endif
