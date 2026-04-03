import Foundation
#if canImport(Combine)
import Combine
#endif

public enum AppDistanceUnitPreference: String, CaseIterable, Identifiable {
    case metric
    case imperial

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .metric: return "Kilometers"
        case .imperial: return "Miles"
        }
    }

    public var shortLabel: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }
}

public enum AppStartTabPreference: String, CaseIterable, Identifiable {
    case overview
    case days
    case insights
    case export
    case live

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .days: return "Days"
        case .insights: return "Insights"
        case .export: return "Export"
        case .live: return "Live"
        }
    }

    var tabIndex: Int {
        switch self {
        case .overview: return 0
        case .days: return 1
        case .insights: return 2
        case .export: return 3
        case .live: return 4
        }
    }
}

public enum AppMapStylePreference: String, CaseIterable, Identifiable {
    case standard
    case hybrid

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid: return "Satellite Hybrid"
        }
    }

    public var isHybrid: Bool {
        self == .hybrid
    }

    mutating func toggle() {
        self = isHybrid ? .standard : .hybrid
    }
}

public enum AppLiveTrackingAccuracyPreference: String, CaseIterable, Identifiable {
    case relaxed
    case balanced
    case strict

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .balanced: return "Balanced"
        case .strict: return "Strict"
        }
    }

    public var detail: String {
        switch self {
        case .relaxed: return "Accepts up to 100 m accuracy."
        case .balanced: return "Accepts up to 65 m accuracy."
        case .strict: return "Accepts up to 25 m accuracy."
        }
    }

    var maximumAcceptedAccuracyM: Double {
        switch self {
        case .relaxed: return 100
        case .balanced: return 65
        case .strict: return 25
        }
    }
}

public enum AppLiveTrackingDetailPreference: String, CaseIterable, Identifiable {
    case batterySaver
    case balanced
    case detailed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .batterySaver: return "Battery Saver"
        case .balanced: return "Balanced"
        case .detailed: return "Detailed"
        }
    }

    public var detail: String {
        switch self {
        case .batterySaver: return "Fewer stored points, larger movement threshold."
        case .balanced: return "Default spacing for local live tracks."
        case .detailed: return "Keeps more movement detail with tighter thresholds."
        }
    }

    var duplicateDistanceThresholdM: Double {
        switch self {
        case .batterySaver: return 5
        case .balanced: return 3
        case .detailed: return 2
        }
    }

    var minimumDistanceDeltaM: Double {
        switch self {
        case .batterySaver: return 25
        case .balanced: return 15
        case .detailed: return 8
        }
    }

    var minimumTimeDeltaS: TimeInterval {
        switch self {
        case .batterySaver: return 15
        case .balanced: return 8
        case .detailed: return 4
        }
    }
}

public enum AppLiveTrackingUploadBatchPreference: String, CaseIterable, Identifiable {
    case immediate
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .immediate: return "Every Point"
        case .small: return "Every 5 Points"
        case .medium: return "Every 15 Points"
        case .large: return "Every 30 Points"
        }
    }

    public var detail: String {
        switch self {
        case .immediate: return "Upload each accepted point as it arrives."
        case .small: return "Batch 5 points before uploading."
        case .medium: return "Batch 15 points before uploading."
        case .large: return "Batch 30 points before uploading."
        }
    }

    public var minimumBatchSize: Int {
        switch self {
        case .immediate: return 1
        case .small: return 5
        case .medium: return 15
        case .large: return 30
        }
    }
}

@MainActor
public final class AppPreferences: ObservableObject {
    private enum Keys {
        static let distanceUnit = "app.preferences.distanceUnit"
        static let startTab = "app.preferences.startTab"
        static let mapStyle = "app.preferences.mapStyle"
        static let showsTechnicalImportDetails = "app.preferences.showsTechnicalImportDetails"
        static let appLanguage = "app.preferences.appLanguage"
        static let liveTrackingAccuracy = "app.preferences.liveTrackingAccuracy"
        static let liveTrackingDetail = "app.preferences.liveTrackingDetail"
        static let liveTrackingBackground = "app.preferences.liveTrackingBackground"
        static let liveTrackingServerUploadEnabled = "app.preferences.liveTrackingServerUploadEnabled"
        static let liveTrackingServerUploadURL = "app.preferences.liveTrackingServerUploadURL"
        static let liveTrackingServerUploadBearerToken = "app.preferences.liveTrackingServerUploadBearerToken"
        static let liveTrackingUploadBatch = "app.preferences.liveTrackingUploadBatch"
        static let recordingInterval = "app.preferences.recordingInterval"
        static let autoRestoreLastImport = "app.preferences.autoRestoreLastImport"
    }

    private let userDefaults: UserDefaults

    @Published public var distanceUnit: AppDistanceUnitPreference {
        didSet { userDefaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit) }
    }

    @Published public var startTab: AppStartTabPreference {
        didSet { userDefaults.set(startTab.rawValue, forKey: Keys.startTab) }
    }

    @Published public var preferredMapStyle: AppMapStylePreference {
        didSet { userDefaults.set(preferredMapStyle.rawValue, forKey: Keys.mapStyle) }
    }

    @Published public var showsTechnicalImportDetails: Bool {
        didSet { userDefaults.set(showsTechnicalImportDetails, forKey: Keys.showsTechnicalImportDetails) }
    }

    @Published public var appLanguage: AppLanguagePreference {
        didSet { userDefaults.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    @Published public var liveTrackingAccuracy: AppLiveTrackingAccuracyPreference {
        didSet { userDefaults.set(liveTrackingAccuracy.rawValue, forKey: Keys.liveTrackingAccuracy) }
    }

    @Published public var liveTrackingDetail: AppLiveTrackingDetailPreference {
        didSet { userDefaults.set(liveTrackingDetail.rawValue, forKey: Keys.liveTrackingDetail) }
    }

    @Published public var allowsBackgroundLiveTracking: Bool {
        didSet { userDefaults.set(allowsBackgroundLiveTracking, forKey: Keys.liveTrackingBackground) }
    }

    @Published public var sendsLiveLocationToServer: Bool {
        didSet { userDefaults.set(sendsLiveLocationToServer, forKey: Keys.liveTrackingServerUploadEnabled) }
    }

    @Published public var liveLocationServerUploadURLString: String {
        didSet { userDefaults.set(liveLocationServerUploadURLString, forKey: Keys.liveTrackingServerUploadURL) }
    }

    @Published public var liveLocationServerUploadBearerToken: String {
        didSet {
            try? KeychainHelper.save(key: Keys.liveTrackingServerUploadBearerToken, value: liveLocationServerUploadBearerToken)
        }
    }

    @Published public var liveTrackingUploadBatch: AppLiveTrackingUploadBatchPreference {
        didSet { userDefaults.set(liveTrackingUploadBatch.rawValue, forKey: Keys.liveTrackingUploadBatch) }
    }

    @Published public var recordingInterval: RecordingIntervalPreference {
        didSet {
            if let data = try? JSONEncoder().encode(recordingInterval) {
                userDefaults.set(data, forKey: Keys.recordingInterval)
            }
        }
    }

    /// When `true`, the app attempts to re-open the most recently imported file on launch.
    /// Defaults to `false` (opt-in behaviour).
    @Published public var autoRestoreLastImport: Bool {
        didSet { userDefaults.set(autoRestoreLastImport, forKey: Keys.autoRestoreLastImport) }
    }

    public var liveTrackRecorderConfiguration: LiveTrackRecorderConfiguration {
        LiveTrackRecorderConfiguration(
            maximumAcceptedAccuracyM: liveTrackingAccuracy.maximumAcceptedAccuracyM,
            duplicateDistanceThresholdM: liveTrackingDetail.duplicateDistanceThresholdM,
            minimumDistanceDeltaM: liveTrackingDetail.minimumDistanceDeltaM,
            minimumTimeDeltaS: liveTrackingDetail.minimumTimeDeltaS,
            minimumPersistedPointCount: 2,
            minimumRecordingIntervalS: recordingInterval.totalSeconds
        )
    }

    public var liveLocationServerUploadConfiguration: LiveLocationServerUploadConfiguration {
        LiveLocationServerUploadConfiguration(
            isEnabled: sendsLiveLocationToServer,
            endpointURLString: liveLocationServerUploadURLString,
            bearerToken: liveLocationServerUploadBearerToken,
            minimumBatchSize: liveTrackingUploadBatch.minimumBatchSize
        )
    }

    public var appLocale: Locale {
        appLanguage.locale
    }

    public func localized(_ english: String) -> String {
        appLanguage.localized(english)
    }

    public func localized(format englishFormat: String, arguments: [CVarArg]) -> String {
        appLanguage.localized(format: englishFormat, arguments: arguments)
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.distanceUnit = Self.loadEnum(
            AppDistanceUnitPreference.self,
            key: Keys.distanceUnit,
            from: userDefaults
        ) ?? .metric
        self.startTab = Self.loadEnum(
            AppStartTabPreference.self,
            key: Keys.startTab,
            from: userDefaults
        ) ?? .overview
        self.preferredMapStyle = Self.loadEnum(
            AppMapStylePreference.self,
            key: Keys.mapStyle,
            from: userDefaults
        ) ?? .standard
        self.showsTechnicalImportDetails = userDefaults.object(forKey: Keys.showsTechnicalImportDetails) as? Bool ?? true
        self.appLanguage = Self.loadEnum(
            AppLanguagePreference.self,
            key: Keys.appLanguage,
            from: userDefaults
        ) ?? .english
        self.liveTrackingAccuracy = Self.loadEnum(
            AppLiveTrackingAccuracyPreference.self,
            key: Keys.liveTrackingAccuracy,
            from: userDefaults
        ) ?? .balanced
        self.liveTrackingDetail = Self.loadEnum(
            AppLiveTrackingDetailPreference.self,
            key: Keys.liveTrackingDetail,
            from: userDefaults
        ) ?? .balanced
        self.allowsBackgroundLiveTracking = userDefaults.object(forKey: Keys.liveTrackingBackground) as? Bool ?? false
        self.sendsLiveLocationToServer = userDefaults.object(forKey: Keys.liveTrackingServerUploadEnabled) as? Bool ?? false
        self.liveLocationServerUploadURLString = userDefaults.string(forKey: Keys.liveTrackingServerUploadURL)
            ?? LiveLocationServerUploadConfiguration.defaultTestEndpointURLString

        // Load token from Keychain. If not present, try migration from UserDefaults.
        if let keychainToken = KeychainHelper.get(key: Keys.liveTrackingServerUploadBearerToken) {
            self.liveLocationServerUploadBearerToken = keychainToken
        } else if let legacyToken = userDefaults.string(forKey: Keys.liveTrackingServerUploadBearerToken) {
            self.liveLocationServerUploadBearerToken = legacyToken
            // Migrate to Keychain
            try? KeychainHelper.save(key: Keys.liveTrackingServerUploadBearerToken, value: legacyToken)
            userDefaults.removeObject(forKey: Keys.liveTrackingServerUploadBearerToken)
        } else {
            self.liveLocationServerUploadBearerToken = ""
        }

        self.liveTrackingUploadBatch = Self.loadEnum(
            AppLiveTrackingUploadBatchPreference.self,
            key: Keys.liveTrackingUploadBatch,
            from: userDefaults
        ) ?? .small
        if let data = userDefaults.data(forKey: Keys.recordingInterval),
           let decoded = try? JSONDecoder().decode(RecordingIntervalPreference.self, from: data) {
            self.recordingInterval = decoded
        } else {
            self.recordingInterval = .default
        }
        self.autoRestoreLastImport = userDefaults.object(forKey: Keys.autoRestoreLastImport) as? Bool ?? false
    }

    public func reset() {
        userDefaults.removeObject(forKey: Keys.distanceUnit)
        userDefaults.removeObject(forKey: Keys.startTab)
        userDefaults.removeObject(forKey: Keys.mapStyle)
        userDefaults.removeObject(forKey: Keys.showsTechnicalImportDetails)
        userDefaults.removeObject(forKey: Keys.appLanguage)
        userDefaults.removeObject(forKey: Keys.liveTrackingAccuracy)
        userDefaults.removeObject(forKey: Keys.liveTrackingDetail)
        userDefaults.removeObject(forKey: Keys.liveTrackingBackground)
        userDefaults.removeObject(forKey: Keys.liveTrackingServerUploadEnabled)
        userDefaults.removeObject(forKey: Keys.liveTrackingServerUploadURL)
        userDefaults.removeObject(forKey: Keys.liveTrackingServerUploadBearerToken)
        KeychainHelper.delete(key: Keys.liveTrackingServerUploadBearerToken)
        userDefaults.removeObject(forKey: Keys.liveTrackingUploadBatch)
        userDefaults.removeObject(forKey: Keys.recordingInterval)
        userDefaults.removeObject(forKey: Keys.autoRestoreLastImport)

        distanceUnit = .metric
        startTab = .overview
        preferredMapStyle = .standard
        showsTechnicalImportDetails = true
        appLanguage = .english
        liveTrackingAccuracy = .balanced
        liveTrackingDetail = .balanced
        allowsBackgroundLiveTracking = false
        sendsLiveLocationToServer = false
        liveLocationServerUploadURLString = LiveLocationServerUploadConfiguration.defaultTestEndpointURLString
        liveLocationServerUploadBearerToken = ""
        liveTrackingUploadBatch = .small
        recordingInterval = .default
        autoRestoreLastImport = false
    }

    private static func loadEnum<T: RawRepresentable>(
        _ type: T.Type,
        key: String,
        from userDefaults: UserDefaults
    ) -> T? where T.RawValue == String {
        guard let rawValue = userDefaults.string(forKey: key) else {
            return nil
        }
        return T(rawValue: rawValue)
    }
}
