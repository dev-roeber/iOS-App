import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Build-158 — UserDefaults-backed Bool-Toggles für den TestFlight-internen
/// Testpfad. Pinpoints: Default OFF, Persistenz, Reset, Namespace-Keys, und
/// strikte Pflicht „nur Boolean-Werte, keine Standortdaten".
///
/// `LocalTimelineTechnicalTestSettings` is `@MainActor`-isolated, so each
/// test hops through `MainActor.assumeIsolated` to touch it. The XCTest
/// harness invokes these tests synchronously on the main thread, which makes
/// the cast safe. Annotating the methods directly with `@MainActor` is not
/// an option because the Linux discovery shim force-casts the method
/// signatures (see `LocationHistoryConsumerPackageDiscoveredTests.derived`).
final class LocalTimelineTechnicalTestSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "LH2GPXTechToggle-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testDefaultsAreOff() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            XCTAssertFalse(s.localTimelineStoreTestModeEnabled)
            XCTAssertFalse(s.importMemoryLoggingEnabled)
        }
    }

    func testTogglePersistsToUserDefaults() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            s.localTimelineStoreTestModeEnabled = true
            s.importMemoryLoggingEnabled = true
            XCTAssertTrue(defaults.bool(
                forKey: LocalTimelineTechnicalTestSettings.Keys.localTimelineStoreTestModeEnabled
            ))
            XCTAssertTrue(defaults.bool(
                forKey: LocalTimelineTechnicalTestSettings.Keys.importMemoryLoggingEnabled
            ))
        }
    }

    func testReinitReadsPersistedValues() {
        defaults.set(true,
                     forKey: LocalTimelineTechnicalTestSettings.Keys.localTimelineStoreTestModeEnabled)
        defaults.set(true,
                     forKey: LocalTimelineTechnicalTestSettings.Keys.importMemoryLoggingEnabled)
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            XCTAssertTrue(s.localTimelineStoreTestModeEnabled)
            XCTAssertTrue(s.importMemoryLoggingEnabled)
        }
    }

    func testResetReturnsToDefaults() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            s.localTimelineStoreTestModeEnabled = true
            s.importMemoryLoggingEnabled = true
            s.reset()
            XCTAssertFalse(s.localTimelineStoreTestModeEnabled)
            XCTAssertFalse(s.importMemoryLoggingEnabled)
            XCTAssertFalse(defaults.bool(
                forKey: LocalTimelineTechnicalTestSettings.Keys.localTimelineStoreTestModeEnabled
            ))
            XCTAssertFalse(defaults.bool(
                forKey: LocalTimelineTechnicalTestSettings.Keys.importMemoryLoggingEnabled
            ))
        }
    }

    func testKeysAreNamespaced() {
        XCTAssertEqual(
            LocalTimelineTechnicalTestSettings.Keys.localTimelineStoreTestModeEnabled,
            "LH2GPX.localTimelineStoreTestModeEnabled"
        )
        XCTAssertEqual(
            LocalTimelineTechnicalTestSettings.Keys.importMemoryLoggingEnabled,
            "LH2GPX.importMemoryLoggingEnabled"
        )
    }

    func testFeatureFlagsResolverActivatesViaSettings() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            XCTAssertFalse(LocalTimelineFeatureFlags.resolve(
                arguments: [], environment: [:], settings: s
            ).isLocalTimelineStoreEnabled, "default off")

            s.localTimelineStoreTestModeEnabled = true
            XCTAssertTrue(LocalTimelineFeatureFlags.resolve(
                arguments: [], environment: [:], settings: s
            ).isLocalTimelineStoreEnabled, "settings turn on")
        }
    }

    func testFeatureFlagsArgsStillActivateIndependentlyOfSettings() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            // Arg path activates even when setting is off.
            let flags = LocalTimelineFeatureFlags.resolve(
                arguments: ["--LH2GPX_LOCAL_TIMELINE_STORE"],
                environment: [:],
                settings: s
            )
            XCTAssertTrue(flags.isLocalTimelineStoreEnabled)
        }
    }

    func testFeatureFlagsEnvStillActivatesIndependentlyOfSettings() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            let flags = LocalTimelineFeatureFlags.resolve(
                arguments: [],
                environment: ["LH2GPX_LOCAL_TIMELINE_STORE": "1"],
                settings: s
            )
            XCTAssertTrue(flags.isLocalTimelineStoreEnabled)
        }
    }

    func testImportMemoryProbeActivationViaSettings() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            XCTAssertFalse(ImportMemoryProbe.isEnabledForEnvironment(
                [:], arguments: [], settings: s
            ), "default off")

            s.importMemoryLoggingEnabled = true
            XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
                [:], arguments: [], settings: s
            ), "settings turn on")
        }
    }

    func testImportMemoryProbeEnvStillActivatesIndependentlyOfSettings() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
                ["LH2GPX_IMPORT_MEMORY_LOG": "1"], arguments: [], settings: s
            ))
        }
    }

    func testImportMemoryProbeArgStillActivatesIndependentlyOfSettings() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
                [:], arguments: ["--LH2GPX_IMPORT_MEMORY_LOG"], settings: s
            ))
        }
    }

    /// Regression-Pin: nur Booleans, keine Strings/Daten in den Toggle-Keys.
    /// Damit dokumentieren wir den Datenschutz-Vertrag (keine Standortdaten,
    /// Pfade oder Tokens in diesen Keys).
    func testOnlyBoolsAreStoredUnderToggleKeys() {
        MainActor.assumeIsolated {
            let s = LocalTimelineTechnicalTestSettings(userDefaults: defaults)
            s.localTimelineStoreTestModeEnabled = true
            s.importMemoryLoggingEnabled = true
            let raw1 = defaults.object(
                forKey: LocalTimelineTechnicalTestSettings.Keys.localTimelineStoreTestModeEnabled
            )
            let raw2 = defaults.object(
                forKey: LocalTimelineTechnicalTestSettings.Keys.importMemoryLoggingEnabled
            )
            XCTAssertTrue(raw1 is Bool || raw1 is NSNumber)
            XCTAssertTrue(raw2 is Bool || raw2 is NSNumber)
            XCTAssertFalse(raw1 is String)
            XCTAssertFalse(raw2 is String)
            XCTAssertFalse(raw1 is Data)
            XCTAssertFalse(raw2 is Data)
        }
    }
}
