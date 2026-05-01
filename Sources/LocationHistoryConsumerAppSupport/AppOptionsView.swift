#if canImport(SwiftUI)
import SwiftUI

// MARK: - AppOptionsView

/// Options main page. Each settings group appears as a dark card row that navigates
/// to the dedicated sub-page. No settings are edited directly on this screen.
public struct AppOptionsView: View {
    @ObservedObject private var preferences: AppPreferences
    private let liveActivityAvailability: LiveActivityFeatureAvailability

    public init(preferences: AppPreferences) {
        self._preferences = ObservedObject(wrappedValue: preferences)
        self.liveActivityAvailability = .current()
    }

    public var body: some View {
        ScrollView {
            LHPageScaffold {
                sectionLink(
                    icon: "gearshape",
                    title: t("General"),
                    description: t("Display, language and import options"),
                    color: LH2GPXTheme.primaryBlue,
                    identifier: "options.general"
                ) {
                    AppGeneralOptionsView(preferences: preferences)
                }

                sectionLink(
                    icon: "map",
                    title: t("Maps"),
                    description: t("Default style for all map views"),
                    color: .teal,
                    identifier: "options.maps"
                ) {
                    AppMapsOptionsView(preferences: preferences)
                }

                sectionLink(
                    icon: "square.and.arrow.down",
                    title: t("Import"),
                    description: t("Auto-restore and import behaviour"),
                    color: .indigo,
                    identifier: "options.import"
                ) {
                    AppImportOptionsView(preferences: preferences)
                }

                sectionLink(
                    icon: "record.circle",
                    title: t("Live Recording"),
                    description: t("Accuracy, interval and background recording"),
                    color: LH2GPXTheme.liveMint,
                    identifier: "options.liveRecording"
                ) {
                    AppLiveRecordingOptionsView(preferences: preferences)
                }

                sectionLink(
                    icon: "arrow.up.circle",
                    title: t("Upload"),
                    description: t("Server URL, token and batch settings"),
                    color: LH2GPXTheme.warningOrange,
                    identifier: "options.upload"
                ) {
                    AppUploadOptionsView(preferences: preferences)
                }

                sectionLink(
                    icon: "dot.radiowaves.left.and.right",
                    title: t("Widget & Live Activity"),
                    description: t("Dynamic Island value and home widget"),
                    color: LH2GPXTheme.liveMint,
                    identifier: "options.widgetLiveActivity"
                ) {
                    AppWidgetLiveActivityOptionsView(
                        preferences: preferences,
                        availability: liveActivityAvailability
                    )
                }

                sectionLink(
                    icon: "hand.raised",
                    title: t("Privacy"),
                    description: t("Storage location and optional upload disclosure"),
                    color: LH2GPXTheme.successGreen,
                    identifier: "options.privacy"
                ) {
                    AppPrivacyOptionsView(preferences: preferences)
                }

                sectionLink(
                    icon: "wrench.and.screwdriver",
                    title: t("Technical"),
                    description: t("Reset all options to defaults"),
                    color: LH2GPXTheme.dangerRed,
                    identifier: "options.technical"
                ) {
                    AppTechnicalOptionsView(preferences: preferences)
                }
            }
        }
        .navigationTitle(t("Options"))
        .accessibilityIdentifier("options.title")
    }

    @ViewBuilder
    private func sectionLink<D: View>(
        icon: String,
        title: String,
        description: String,
        color: Color,
        identifier: String,
        @ViewBuilder destination: @escaping () -> D
    ) -> some View {
        NavigationLink { destination() } label: {
            LHOptionsSectionRow(icon: icon, title: title, description: description, color: color)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(LH2GPXTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier(identifier)
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppGeneralOptionsView

struct AppGeneralOptionsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        Form {
            Section {
                Picker(t("Distance Units"), selection: $preferences.distanceUnit) {
                    ForEach(AppDistanceUnitPreference.allCases) { unit in
                        Text(t(unit.title)).tag(unit)
                    }
                }
                Picker(t("Start Tab"), selection: $preferences.startTab) {
                    ForEach(AppStartTabPreference.allCases) { tab in
                        Text(t(tab.title)).tag(tab)
                    }
                }
                Toggle(t("Show Technical Import Details"), isOn: $preferences.showsTechnicalImportDetails)
                Picker(t("App Language"), selection: $preferences.appLanguage) {
                    ForEach(AppLanguagePreference.allCases) { language in
                        Text(t(language.title)).tag(language)
                    }
                }
            } header: { Text(t("General")) }
        }
        .navigationTitle(t("General"))
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppMapsOptionsView

struct AppMapsOptionsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        Form {
            Section {
                Picker(t("Default Map Style"), selection: $preferences.preferredMapStyle) {
                    ForEach(AppMapStylePreference.allCases) { style in
                        Text(t(style.title)).tag(style)
                    }
                }
            } header: { Text(t("Maps")) }
              footer: { Text(t("Applies to the day-detail map and live-location map.")) }
        }
        .navigationTitle(t("Maps"))
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppImportOptionsView

struct AppImportOptionsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        Form {
            Section {
                Toggle(t("Restore Last Import on Launch"), isOn: $preferences.autoRestoreLastImport)
            } header: { Text(t("Import")) }
              footer: { Text(t("When enabled, the app tries to reopen the last imported file on startup. Missing or stale files are skipped automatically.")) }
        }
        .navigationTitle(t("Import"))
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppLiveRecordingOptionsView

struct AppLiveRecordingOptionsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        ScrollView {
            LHPageScaffold {
                // Preset selector card
                LHCard {
                    LHSectionHeader(t("Recording Preset"))
                    LHLiveRecordingPresetSelector(
                        preset: Binding(
                            get: { preferences.recordingPreset },
                            set: { preferences.recordingPreset = $0 }
                        ),
                        t: t
                    )
                    Text(presetHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Settings card
                LHCard {
                    LHSectionHeader(t("Settings"))

                    Divider().foregroundStyle(LH2GPXTheme.separator)

                    accuracyRow
                    Divider().foregroundStyle(LH2GPXTheme.separator)
                    motionFilterRow
                    Divider().foregroundStyle(LH2GPXTheme.separator)
                    updateIntervalRow

                    if preferences.recordingPreset == .custom {
                        Divider().foregroundStyle(LH2GPXTheme.separator)
                        minimumDistanceRow
                        Divider().foregroundStyle(LH2GPXTheme.separator)
                        maximumGapRow
                    }

                    Divider().foregroundStyle(LH2GPXTheme.separator)
                    foregroundRecordingRow
                    Divider().foregroundStyle(LH2GPXTheme.separator)
                    backgroundToggle
                }
            }
        }
        .navigationTitle(t("Live Recording"))
    }

    private var accuracyRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("High-Accuracy Location"))
                    .font(.subheadline)
                Text(t(preferences.liveTrackingAccuracy.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if preferences.recordingPreset == .custom {
                Picker("", selection: $preferences.liveTrackingAccuracy) {
                    ForEach(AppLiveTrackingAccuracyPreference.allCases) { mode in
                        Text(t(mode.title)).tag(mode)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("options.live.highAccuracy")
            } else {
                Text(t(preferences.liveTrackingAccuracy.title))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var motionFilterRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("Motion Filter"))
                    .font(.subheadline)
                Text(t(preferences.liveTrackingDetail.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if preferences.recordingPreset == .custom {
                Picker("", selection: $preferences.liveTrackingDetail) {
                    ForEach(AppLiveTrackingDetailPreference.allCases) { mode in
                        Text(t(mode.title)).tag(mode)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("options.live.motionFilter")
            } else {
                Text(t(preferences.liveTrackingDetail.title))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var updateIntervalRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Update Interval"))
                .font(.subheadline)
            HStack(spacing: 4) {
                Text(localizedMinimumTimeGapDescription)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { preferences.recordingInterval.unit },
                    set: { preferences.recordingInterval = .validated(value: preferences.recordingInterval.value, unit: $0) }
                )) {
                    ForEach(RecordingIntervalUnit.allCases) { unit in
                        Text(t(unit.displayName)).tag(unit)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Stepper(onIncrement: incrementMinimumTimeGap, onDecrement: decrementMinimumTimeGap) { EmptyView() }
            }
            .accessibilityIdentifier("options.live.interval")
        }
    }

    private var minimumDistanceRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("Minimum Distance Filter"))
                    .font(.subheadline)
                Text("\(Int(preferences.liveTrackingDetail.minimumDistanceDeltaM)) m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityIdentifier("options.live.minimumDistance")
    }

    private var maximumGapRow: some View {
        HStack {
            Text(t("Maximum Time Gap"))
                .font(.subheadline)
            Spacer()
            Picker("", selection: $preferences.maximumRecordingGapSeconds) {
                Text(t("1 min")).tag(60)
                Text(t("5 min")).tag(300)
                Text(t("15 min")).tag(900)
                Text(t("30 min")).tag(1800)
                Text(t("Unlimited")).tag(0)
            }
            .labelsHidden()
        }
    }

    private var foregroundRecordingRow: some View {
        HStack {
            Text(t("Foreground recording"))
                .font(.subheadline)
            Spacer()
            LHStatusChip(
                title: t("Active"),
                systemImage: "checkmark.circle.fill",
                color: LH2GPXTheme.liveMint
            )
        }
        .accessibilityIdentifier("options.live.foregroundOnly")
    }

    private var backgroundToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(t("Allow Background Recording"), isOn: $preferences.allowsBackgroundLiveTracking)
                .accessibilityIdentifier("options.live.background")
            Text(t("Background recording requires Always Allow permission and only affects local live-track recording."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetHint: String {
        switch preferences.recordingPreset {
        case .battery:  return t("Fewer stored points, larger movement threshold.")
        case .balanced: return t("Default spacing for local live tracks.")
        case .precise:  return t("Keeps more movement detail with tighter thresholds.")
        case .custom:   return t("Advanced settings active. Choosing a preset will overwrite current values.")
        }
    }

    private var localizedMinimumTimeGapDescription: String {
        let interval = preferences.recordingInterval
        guard !interval.hasNoMinimum else { return t(interval.displayString) }
        let unitKey = interval.value == 1 ? interval.unit.singularKey : interval.unit.rawValue
        return "\(interval.value) \(t(unitKey))"
    }

    private func incrementMinimumTimeGap() {
        let current = preferences.recordingInterval
        let nextValue = current.value == Int.max ? Int.max : current.value + 1
        preferences.recordingInterval = .validated(value: nextValue, unit: current.unit)
    }

    private func decrementMinimumTimeGap() {
        let current = preferences.recordingInterval
        preferences.recordingInterval = .validated(value: current.value - 1, unit: current.unit)
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppUploadOptionsView

struct AppUploadOptionsView: View {
    @ObservedObject var preferences: AppPreferences
    @State private var connectionTestResult: UploadConnectionTestResult? = nil
    @State private var isTestingConnection = false

    var body: some View {
        ScrollView {
            LHPageScaffold {
                LHCard {
                    LHSectionHeader(t("Upload"))
                    LHUploadSettingsCard(preferences: preferences, t: t)
                }

                if preferences.sendsLiveLocationToServer,
                   preferences.liveLocationServerUploadConfiguration.endpointURL != nil {
                    LHCard {
                        if isTestingConnection {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text(t("Testing…")).foregroundStyle(.secondary)
                            }
                        } else if let result = connectionTestResult {
                            LHStatusChip(
                                title: result == .reachable ? t("Reachable") : t("Unreachable"),
                                systemImage: result == .reachable
                                    ? "checkmark.circle.fill" : "xmark.circle.fill",
                                color: result == .reachable
                                    ? LH2GPXTheme.successGreen : LH2GPXTheme.dangerRed
                            )
                        }
                        Button(t("Test Connection"), action: testConnection)
                            .foregroundStyle(LH2GPXTheme.primaryBlue)
                    }
                }

                LHInsightBanner(
                    title: t("Upload"),
                    message: t("Accepted live-recording points only. Use an HTTP(S) endpoint you control."),
                    systemImage: "info.circle",
                    tint: LH2GPXTheme.warningOrange
                )
            }
        }
        .navigationTitle(t("Upload"))
    }

    private func testConnection() {
        guard let url = preferences.liveLocationServerUploadConfiguration.endpointURL else { return }
        isTestingConnection = true
        connectionTestResult = nil

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "HEAD"
        if !preferences.liveLocationServerUploadBearerToken.isEmpty {
            request.setValue(
                "Bearer \(preferences.liveLocationServerUploadBearerToken)",
                forHTTPHeaderField: "Authorization"
            )
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                self.isTestingConnection = false
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 500 {
                    self.connectionTestResult = .reachable
                } else if error == nil, response != nil {
                    self.connectionTestResult = .reachable
                } else {
                    self.connectionTestResult = .unreachable
                }
            }
        }.resume()
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

private enum UploadConnectionTestResult {
    case reachable
    case unreachable
}

// MARK: - AppWidgetLiveActivityOptionsView

struct AppWidgetLiveActivityOptionsView: View {
    @ObservedObject var preferences: AppPreferences
    let availability: LiveActivityFeatureAvailability

    init(preferences: AppPreferences, availability: LiveActivityFeatureAvailability) {
        self._preferences = ObservedObject(wrappedValue: preferences)
        self.availability = availability
    }

    var body: some View {
        ScrollView {
            LHPageScaffold {
                // Dynamic Island
                LHCard {
                    LHSectionHeader(t("Dynamic Island Primary Value"))

                    LHDynamicIslandPreviewCard(
                        display: preferences.dynamicIslandCompactDisplay,
                        availability: availability,
                        t: t
                    )

                    if availability.isConfigurable {
                        Divider().foregroundStyle(LH2GPXTheme.separator)
                        Picker(t("Dynamic Island Primary Value"), selection: $preferences.dynamicIslandCompactDisplay) {
                            ForEach(DynamicIslandCompactDisplay.allCases, id: \.self) { display in
                                Text(t(display.localizedName)).tag(display)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("options.dynamicIsland.value")
                    }

                    Text(t("Active only during recording"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Home Widget
                LHCard {
                    LHSectionHeader(t("Home Widget"))

                    LHWidgetPreviewCard(distanceUnit: preferences.distanceUnit, t: t)

                    Divider().foregroundStyle(LH2GPXTheme.separator)

                    Toggle(t("Automatic Widget Update"), isOn: $preferences.widgetAutoUpdate)

                    Text(t("The widget updates automatically after each recording."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !availability.isConfigurable {
                    LHInsightBanner(
                        title: t("Live Activity"),
                        message: t(availability.detailMessage),
                        systemImage: "exclamationmark.circle",
                        tint: .secondary
                    )
                }
            }
        }
        .navigationTitle(t("Widget & Live Activity"))
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppPrivacyOptionsView

struct AppPrivacyOptionsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        ScrollView {
            LHPageScaffold {
                LHCard {
                    LHSectionHeader(t("Privacy"))

                    privacyRow(label: t("Location Data"), value: t("Stored locally on this device"))
                    Divider().foregroundStyle(LH2GPXTheme.separator)
                    privacyRow(label: t("Server Upload"), value: serverUploadPrivacyValue)
                    Divider().foregroundStyle(LH2GPXTheme.separator)
                    privacyRow(
                        label: t("Live Recording"),
                        value: preferences.allowsBackgroundLiveTracking
                            ? t("Foreground + optional background")
                            : t("Foreground only")
                    )

                    Text(t("This app keeps imports and live tracks local by default. Server upload is optional, user-controlled and only sends accepted live-recording points to the configured endpoint."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(t("Privacy"))
    }

    private func privacyRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private var serverUploadPrivacyValue: String {
        guard preferences.sendsLiveLocationToServer else { return t("Disabled") }
        return preferences.liveLocationServerUploadConfiguration.endpointURL == nil
            ? t("Enabled (invalid URL)") : t("Enabled")
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

// MARK: - AppTechnicalOptionsView

struct AppTechnicalOptionsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        ScrollView {
            LHPageScaffold {
                LHCard {
                    LHSectionHeader(t("Technical"))

                    Button(t("Reset Options")) {
                        preferences.reset()
                    }
                    .foregroundStyle(LH2GPXTheme.dangerRed)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(t("Resets all app preferences to their default values. Live tracks and imported data are not affected."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(t("Technical"))
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

#endif
