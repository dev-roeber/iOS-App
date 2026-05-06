#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHOptionsSectionRow

/// Tappable navigation row for the options main page.
/// Icon badge · title · one-line description · trailing chevron.
public struct LHOptionsSectionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    public init(icon: String, title: String, description: String, color: Color = LH2GPXTheme.primaryBlue) {
        self.icon = icon
        self.title = title
        self.description = description
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - LHLiveRecordingPresetSelector

/// Horizontal chip selector for the four recording presets.
public struct LHLiveRecordingPresetSelector: View {
    @Binding var preset: RecordingPreset
    let t: (String) -> String

    public init(preset: Binding<RecordingPreset>, t: @escaping (String) -> String) {
        self._preset = preset
        self.t = t
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(RecordingPreset.allCases, id: \.self) { p in
                presetChip(p)
            }
        }
    }

    @ViewBuilder
    private func presetChip(_ p: RecordingPreset) -> some View {
        let active = preset == p
        let chipColor = color(for: p)
        Button { preset = p } label: {
            Text(t(p.title))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(active ? chipColor.opacity(0.16) : LH2GPXTheme.chipBackground)
                .foregroundStyle(active ? chipColor : Color.secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(p.accessibilityIdentifier)
    }

    private func color(for preset: RecordingPreset) -> Color {
        switch preset {
        case .battery:  return LH2GPXTheme.successGreen
        case .balanced: return LH2GPXTheme.primaryBlue
        case .precise:  return LH2GPXTheme.liveMint
        case .custom:   return LH2GPXTheme.warningOrange
        }
    }
}

// MARK: - LHUploadSettingsCard

/// Upload settings card — bearer token always shown as a masked SecureField.
/// Tokens are never displayed in plain text.
public struct LHUploadSettingsCard: View {
    @ObservedObject var preferences: AppPreferences
    let t: (String) -> String

    public init(preferences: AppPreferences, t: @escaping (String) -> String) {
        self._preferences = ObservedObject(wrappedValue: preferences)
        self.t = t
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(t("Upload to Your Own Server"), isOn: $preferences.sendsLiveLocationToServer)
                .accessibilityIdentifier("options.upload.enabled")

            if preferences.sendsLiveLocationToServer {
                Divider().foregroundStyle(LH2GPXTheme.separator)
                uploadURLField
                tokenField
                batchPicker
                uploadStatusRow
            }
        }
    }

    private var uploadURLField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Upload URL"))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(t("Server URL"), text: $preferences.liveLocationServerUploadURLString)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                .font(.subheadline)
                .accessibilityIdentifier("options.upload.url")
        }
    }

    private var tokenField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Bearer Token"))
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField(
                preferences.liveLocationServerUploadBearerToken.isEmpty
                    ? t("Token not set") : t("Token saved"),
                text: $preferences.liveLocationServerUploadBearerToken
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()
            .font(.subheadline)
            .accessibilityIdentifier("options.upload.token")
        }
    }

    private var batchPicker: some View {
        HStack {
            Text(t("Points per Batch"))
                .font(.subheadline)
            Spacer()
            Picker("", selection: $preferences.liveTrackingUploadBatch) {
                ForEach(AppLiveTrackingUploadBatchPreference.allCases) { batch in
                    Text(t(batch.title)).tag(batch)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("options.upload.batch")
        }
    }

    private var uploadStatusRow: some View {
        let hasValidURL = preferences.liveLocationServerUploadConfiguration.endpointURL != nil
        return HStack(spacing: 6) {
            Circle()
                .fill(OptionsPresentation.uploadStatusColor(
                    sendsToServer: preferences.sendsLiveLocationToServer,
                    hasValidURL: hasValidURL
                ))
                .frame(width: 8, height: 8)
            Text(t(OptionsPresentation.uploadStatusText(
                sendsToServer: preferences.sendsLiveLocationToServer,
                hasValidURL: hasValidURL
            )))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - LHDynamicIslandPreviewCard

/// Info card showing the active Dynamic Island primary value and availability state.
public struct LHDynamicIslandPreviewCard: View {
    let display: DynamicIslandCompactDisplay
    let availability: LiveActivityFeatureAvailability
    let t: (String) -> String

    public init(
        display: DynamicIslandCompactDisplay,
        availability: LiveActivityFeatureAvailability,
        t: @escaping (String) -> String
    ) {
        self.display = display
        self.availability = availability
        self.t = t
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.liveMint)
                .frame(width: 34, height: 34)
                .background(LH2GPXTheme.liveMint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(t("Dynamic Island"))
                    .font(.subheadline.weight(.semibold))
                Text(availability.isConfigurable ? t(display.localizedName) : t(availability.statusLabel))
                    .font(.caption)
                    .foregroundStyle(availability.isConfigurable ? LH2GPXTheme.liveMint : Color.secondary)
            }

            Spacer()

            LHStatusChip(
                title: availability.isConfigurable ? t("Available") : t("Unavailable"),
                systemImage: availability.isConfigurable ? "checkmark.circle.fill" : "xmark.circle",
                color: availability.isConfigurable ? LH2GPXTheme.liveMint : .secondary
            )
        }
        .accessibilityIdentifier("options.dynamicIsland.preview")
    }
}

// MARK: - LHWidgetPreviewCard

/// Compact info card describing the home-screen widget content.
public struct LHWidgetPreviewCard: View {
    let distanceUnit: AppDistanceUnitPreference
    let t: (String) -> String

    public init(distanceUnit: AppDistanceUnitPreference, t: @escaping (String) -> String) {
        self.distanceUnit = distanceUnit
        self.t = t
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.primaryBlue)
                .frame(width: 34, height: 34)
                .background(LH2GPXTheme.primaryBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(t("Home Widget"))
                    .font(.subheadline.weight(.semibold))
                Text("\(t("Last tour + weekly status")) · \(distanceUnit == .metric ? t("Kilometers") : t("Miles"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .accessibilityIdentifier("options.widget.preview")
    }
}

#endif
