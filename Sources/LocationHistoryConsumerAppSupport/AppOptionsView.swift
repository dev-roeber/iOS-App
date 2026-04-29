#if canImport(SwiftUI)
import SwiftUI

public struct AppOptionsView: View {
    @ObservedObject private var preferences: AppPreferences
    @State private var connectionTestResult: ConnectionTestResult? = nil
    @State private var isTestingConnection = false
    private let liveActivityAvailability: LiveActivityFeatureAvailability

    public init(preferences: AppPreferences) {
        self._preferences = ObservedObject(wrappedValue: preferences)
        self.liveActivityAvailability = .current()
    }

    public var body: some View {
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
            } header: {
                Text(t("Display"))
            } footer: {
                Text(t("Controls how much metadata the app shows around imports and source information."))
            }

            Section {
                Picker(t("Default Map Style"), selection: $preferences.preferredMapStyle) {
                    ForEach(AppMapStylePreference.allCases) { style in
                        Text(t(style.title)).tag(style)
                    }
                }
            } header: {
                Text(t("Maps"))
            } footer: {
                Text(t("Applies to the day-detail map and live-location map."))
            }

            Section {
                Toggle(t("Restore Last Import on Launch"), isOn: $preferences.autoRestoreLastImport)
            } header: {
                Text(t("Imports"))
            } footer: {
                Text(t("When enabled, the app tries to reopen the last imported file on startup. Missing or stale files are skipped automatically."))
            }

            Section {
                Picker(t("App Language"), selection: $preferences.appLanguage) {
                    ForEach(AppLanguagePreference.allCases) { language in
                        Text(t(language.title)).tag(language)
                    }
                }

                Toggle(t("Upload to Custom Server"), isOn: $preferences.sendsLiveLocationToServer)

                if preferences.sendsLiveLocationToServer {
                    TextField(t("Server URL"), text: $preferences.liveLocationServerUploadURLString)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()

                    SecureField(t("Bearer Token (optional)"), text: $preferences.liveLocationServerUploadBearerToken)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                if preferences.sendsLiveLocationToServer {
                    Picker(t("Upload Batch Size"), selection: $preferences.liveTrackingUploadBatch) {
                        ForEach(AppLiveTrackingUploadBatchPreference.allCases) { batch in
                            Text(t(batch.title)).tag(batch)
                        }
                    }

                    LabeledContent(t("Upload Status")) {
                        Text(uploadStatusText)
                            .foregroundStyle(uploadStatusColor)
                    }
                }

                if preferences.sendsLiveLocationToServer,
                   preferences.liveLocationServerUploadConfiguration.endpointURL != nil {
                    if isTestingConnection {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(t("Testing…"))
                                .foregroundStyle(.secondary)
                        }
                    } else if let result = connectionTestResult {
                        LabeledContent(t("Connection")) {
                            Text(result == .reachable ? t("Reachable") : t("Unreachable"))
                                .foregroundStyle(result == .reachable ? .green : .red)
                        }
                    }

                    Button(t("Test Connection")) {
                        testConnection()
                    }
                }

            } header: {
                Text(t("Language and Upload"))
            } footer: {
                Text(t("Accepted live-recording points only. Use an HTTP(S) endpoint you control."))
            }

            Section {
                Picker(t("Accuracy Filter"), selection: $preferences.liveTrackingAccuracy) {
                    ForEach(AppLiveTrackingAccuracyPreference.allCases) { mode in
                        Text(t(mode.title)).tag(mode)
                    }
                }

                LabeledContent(t("Max. GPS Inaccuracy"), value: "\(Int(preferences.liveTrackingAccuracy.maximumAcceptedAccuracyM)) m")

                Picker(t("Recording Detail"), selection: $preferences.liveTrackingDetail) {
                    ForEach(AppLiveTrackingDetailPreference.allCases) { mode in
                        Text(t(mode.title)).tag(mode)
                    }
                }

                LabeledContent(t("Minimum Movement"), value: "\(Int(preferences.liveTrackingDetail.minimumDistanceDeltaM)) m")

                Toggle(t("Allow Background Recording"), isOn: $preferences.allowsBackgroundLiveTracking)

                LabeledContent(t("Minimum Time Gap")) {
                    HStack(spacing: 4) {
                        Text(localizedMinimumTimeGapDescription)
                            .monospacedDigit()
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
                        Stepper(
                            onIncrement: incrementMinimumTimeGap,
                            onDecrement: decrementMinimumTimeGap
                        ) { EmptyView() }
                    }
                }

                Picker(t("Maximum Gap"), selection: $preferences.maximumRecordingGapSeconds) {
                    Text(t("1 min")).tag(60)
                    Text(t("5 min")).tag(300)
                    Text(t("15 min")).tag(900)
                    Text(t("30 min")).tag(1800)
                    Text(t("Unlimited")).tag(0)
                }

            } header: {
                Text(t("Live Recording"))
            } footer: {
                Text("\(t(preferences.liveTrackingAccuracy.detail)) \(t(preferences.liveTrackingDetail.detail)) \(t("Minimum Time Gap controls the shortest allowed delay between accepted points. Set it to No minimum to disable the hard floor.")) \(t("Larger minimum gaps reduce point count, battery use and upload frequency.")) \(t("When Maximum Gap is set, a track is automatically split if two consecutive points are further apart in time than the configured value.")) \(t("Recording Detail still tunes the movement-sensitive quality gate.")) \(t("Background recording requires Always Allow permission and only affects local live-track recording."))")
            }

            Section {
                LabeledContent(t("Home Screen Widget")) {
                    Text(t("Last tour + weekly status"))
                        .foregroundStyle(.secondary)
                }

                LabeledContent(t("Unit")) {
                    Text(preferences.distanceUnit == .metric ? t("Kilometers") : t("Miles"))
                        .foregroundStyle(.secondary)
                }

                Toggle(t("Automatic Widget Update"), isOn: $preferences.widgetAutoUpdate)

                LabeledContent(t("Live Activities")) {
                    Text(t(liveActivityAvailability.statusLabel))
                        .foregroundStyle(liveActivityAvailability.isConfigurable ? .green : .secondary)
                }

                Picker(t("Dynamic Island Value"), selection: $preferences.dynamicIslandCompactDisplay) {
                    ForEach(DynamicIslandCompactDisplay.allCases, id: \.self) { display in
                        Text(t(display.localizedName)).tag(display)
                    }
                }
                .disabled(!liveActivityAvailability.isConfigurable)

            } header: {
                Text(t("Widget & Live Activity"))
            } footer: {
                Text("\(t("The widget updates automatically after each recording. The selected Dynamic Island value is shown in compact and expanded Live Activity regions during active recording.")) \(t(liveActivityAvailability.detailMessage))")
            }

            Section {
                LabeledContent(t("Location Data"), value: t("Stored locally on this device"))
                LabeledContent(t("Server Upload"), value: serverUploadPrivacyValue)
                LabeledContent(t("Live Recording"), value: preferences.allowsBackgroundLiveTracking ? t("Foreground + optional background") : t("Foreground only"))
            } header: {
                Text(t("Privacy"))
            } footer: {
                Text(t("This app keeps imports and live tracks local by default. Server upload is optional, user-controlled and only sends accepted live-recording points to the configured endpoint."))
            }

            Section {
                Button(t("Reset Options")) {
                    preferences.reset()
                }
                .foregroundStyle(.red)
            } header: {
                Text(t("Technical"))
            }
        }
        .navigationTitle(t("Options"))
    }

    private var serverUploadPrivacyValue: String {
        guard preferences.sendsLiveLocationToServer else {
            return t("Disabled")
        }
        return preferences.liveLocationServerUploadConfiguration.endpointURL == nil
            ? t("Enabled (invalid URL)")
            : t("Enabled")
    }

    private var uploadStatusText: String {
        guard preferences.sendsLiveLocationToServer else {
            return t("Disabled")
        }
        guard preferences.liveLocationServerUploadConfiguration.endpointURL != nil else {
            return t("Invalid URL")
        }
        return t("Active")
    }

    private var uploadStatusColor: Color {
        guard preferences.sendsLiveLocationToServer else { return .secondary }
        guard preferences.liveLocationServerUploadConfiguration.endpointURL != nil else { return .red }
        return .green
    }

    private var localizedMinimumTimeGapDescription: String {
        let interval = preferences.recordingInterval
        guard !interval.hasNoMinimum else {
            return t(interval.displayString)
        }
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

    private func testConnection() {
        guard let url = preferences.liveLocationServerUploadConfiguration.endpointURL else { return }
        isTestingConnection = true
        connectionTestResult = nil

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "HEAD"
        if !preferences.liveLocationServerUploadBearerToken.isEmpty {
            request.setValue("Bearer \(preferences.liveLocationServerUploadBearerToken)", forHTTPHeaderField: "Authorization")
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

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

private enum ConnectionTestResult {
    case reachable
    case unreachable
}
#endif
