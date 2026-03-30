#if canImport(SwiftUI)
import SwiftUI

public struct AppOptionsView: View {
    @ObservedObject private var preferences: AppPreferences

    public init(preferences: AppPreferences) {
        self._preferences = ObservedObject(wrappedValue: preferences)
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

                    TextField(t("Bearer Token (optional)"), text: $preferences.liveLocationServerUploadBearerToken)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                Picker(t("Upload Batch Size"), selection: $preferences.liveTrackingUploadBatch) {
                    ForEach(AppLiveTrackingUploadBatchPreference.allCases) { batch in
                        Text(t(batch.title)).tag(batch)
                    }
                }

                LabeledContent(t("Test Endpoint"), value: LiveLocationServerUploadConfiguration.defaultTestEndpointURLString)
            } header: {
                Text(t("Language and Upload"))
            } footer: {
                Text(t("Accepted live-recording points only. Use an HTTP(S) endpoint you control. The default test endpoint is prefilled with this server IP and can be changed at any time."))
            }

            Section {
                Picker(t("Accuracy Filter"), selection: $preferences.liveTrackingAccuracy) {
                    ForEach(AppLiveTrackingAccuracyPreference.allCases) { mode in
                        Text(t(mode.title)).tag(mode)
                    }
                }

                Picker(t("Recording Detail"), selection: $preferences.liveTrackingDetail) {
                    ForEach(AppLiveTrackingDetailPreference.allCases) { mode in
                        Text(t(mode.title)).tag(mode)
                    }
                }

                Toggle(t("Allow Background Recording"), isOn: $preferences.allowsBackgroundLiveTracking)

                LabeledContent(t("Accepted Accuracy"), value: "\(Int(preferences.liveTrackRecorderConfiguration.maximumAcceptedAccuracyM)) m")
                LabeledContent(t("Minimum Movement"), value: "\(Int(preferences.liveTrackRecorderConfiguration.minimumDistanceDeltaM)) m")
                LabeledContent(t("Minimum Time Gap"), value: "\(Int(preferences.liveTrackRecorderConfiguration.minimumTimeDeltaS)) s")
            } header: {
                Text(t("Live Recording"))
            } footer: {
                Text("\(t(preferences.liveTrackingAccuracy.detail)) \(t(preferences.liveTrackingDetail.detail)) Background recording requires Always Allow permission and only affects local live-track recording.")
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

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}
#endif
