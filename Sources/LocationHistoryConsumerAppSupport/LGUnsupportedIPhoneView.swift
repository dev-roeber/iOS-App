#if canImport(SwiftUI)
import SwiftUI

public struct LGUnsupportedIPhoneView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "iphone.gen3.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("iOS 26 erforderlich")
                    .font(.title2.weight(.semibold))
                Text("Die neue LH2GPX-Oberfläche benötigt iOS 26 oder neuer. "
                     + "Bitte aktualisiere dein iPhone unter Einstellungen → Allgemein → "
                     + "Softwareupdate.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Text("Auf iPad ist diese App weiterhin unter iOS 17 verfügbar.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LHLiquidGlassBackground().ignoresSafeArea())
    }
}
#endif
