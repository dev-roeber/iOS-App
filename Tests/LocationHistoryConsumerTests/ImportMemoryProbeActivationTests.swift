import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Unit coverage for the activation rules behind `ImportMemoryProbe`. Both
/// activation paths — `ProcessInfo.environment[LH2GPX_IMPORT_MEMORY_LOG]`
/// and any of the four launch-argument spellings — must be honoured, and
/// neither path may fire on unrelated inputs. The tests target the pure
/// `isEnabledForEnvironment(_:arguments:)` entry point so the global
/// `isEnabled` cache is not touched and the suite stays Linux-buildable
/// (Codex P0 Aufgabe B). `AppBuildInfo.isMemoryLoggingEnabled` is
/// double-checked because the build-info screen is the only at-a-glance
/// signal a tester has on-device.
final class ImportMemoryProbeActivationTests: XCTestCase {

    // MARK: - Environment path

    func testEnvSetTo1Enables() {
        XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
            [ImportMemoryProbe.launchArgumentKey: "1"],
            arguments: []
        ))
    }

    func testEnvSetTo0DoesNotEnable() {
        XCTAssertFalse(ImportMemoryProbe.isEnabledForEnvironment(
            [ImportMemoryProbe.launchArgumentKey: "0"],
            arguments: []
        ))
    }

    func testEnvSetToTrueDoesNotEnable() {
        // Only the exact string "1" counts — "true", "yes", "YES" are all
        // refused so testers can't accidentally enable the probe with the
        // wrong literal.
        XCTAssertFalse(ImportMemoryProbe.isEnabledForEnvironment(
            [ImportMemoryProbe.launchArgumentKey: "true"],
            arguments: []
        ))
    }

    func testEnvUnsetWithoutArgsIsDisabled() {
        XCTAssertFalse(ImportMemoryProbe.isEnabledForEnvironment(
            [:],
            arguments: []
        ))
    }

    // MARK: - Launch-argument path

    func testArgPlainKeyEnables() {
        XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
            [:],
            arguments: [ImportMemoryProbe.launchArgumentKey]
        ))
    }

    func testArgWithSingleDashEnables() {
        XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
            [:],
            arguments: ["-\(ImportMemoryProbe.launchArgumentKey)"]
        ))
    }

    func testArgWithDoubleDashEnables() {
        XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
            [:],
            arguments: ["--\(ImportMemoryProbe.launchArgumentKey)"]
        ))
    }

    func testArgKeyEqualsOneEnables() {
        XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
            [:],
            arguments: ["\(ImportMemoryProbe.launchArgumentKey)=1"]
        ))
    }

    func testArgKeyEqualsZeroDoesNotEnable() {
        // `KEY=0` must NOT enable the probe — only `KEY=1` (or the bare/dashed
        // forms) qualifies. Mirrors the env-side strictness.
        XCTAssertFalse(ImportMemoryProbe.isEnabledForEnvironment(
            [:],
            arguments: ["\(ImportMemoryProbe.launchArgumentKey)=0"]
        ))
    }

    // MARK: - Combined / negative inputs

    func testEnvAndArgsBothSetEnables() {
        XCTAssertTrue(ImportMemoryProbe.isEnabledForEnvironment(
            [ImportMemoryProbe.launchArgumentKey: "1"],
            arguments: [ImportMemoryProbe.launchArgumentKey]
        ))
    }

    func testUnrelatedEnvAndArgsAreIgnored() {
        XCTAssertFalse(ImportMemoryProbe.isEnabledForEnvironment(
            ["FOO": "bar"],
            arguments: ["--bar"]
        ))
    }

    func testIsEnabledForEnvironmentIsPure() {
        // Idempotency check — the function is documented as a pure rule, so
        // two consecutive invocations with identical inputs must return the
        // same value with no hidden caching side-effects.
        let env = [ImportMemoryProbe.launchArgumentKey: "1"]
        let args: [String] = []
        let first = ImportMemoryProbe.isEnabledForEnvironment(env, arguments: args)
        let second = ImportMemoryProbe.isEnabledForEnvironment(env, arguments: args)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first)

        let disabledEnv: [String: String] = [:]
        let disabledFirst = ImportMemoryProbe.isEnabledForEnvironment(disabledEnv, arguments: [])
        let disabledSecond = ImportMemoryProbe.isEnabledForEnvironment(disabledEnv, arguments: [])
        XCTAssertEqual(disabledFirst, disabledSecond)
        XCTAssertFalse(disabledFirst)
    }

    // MARK: - Disabled-state safety

    func testLogEveryIsNoOpWhenDisabled() {
        // We can't intercept stdout from inside XCTest cleanly, but we CAN
        // assert that calling `logEvery` on a disabled probe neither crashes
        // nor throws. The probe's documented contract is "side-effect free
        // when disabled".
        ImportMemoryProbe.logEvery("test", counter: 1000, every: 1000)
        // Bonus: edge-case inputs must also not crash regardless of state.
        ImportMemoryProbe.logEvery("test", counter: 0, every: 1000)
        ImportMemoryProbe.logEvery("test", counter: 1000, every: 0)
    }

    // MARK: - Snapshot shape

    func testCurrentFootprintReturnsSnapshotShape() {
        // Under SwiftPM on Linux both fields are nil; on Darwin both are
        // populated. We only assert the shape — no concrete > 0 check —
        // so the test stays portable.
        let snapshot = ImportMemoryProbe.currentFootprintMB()
        // Compile-time shape check: properties are `Double?`. Touching them
        // here both documents intent and exercises the API surface.
        _ = snapshot.footprintMB
        _ = snapshot.residentMB
        XCTAssertTrue(type(of: snapshot) == ImportMemoryProbe.Snapshot.self)
    }

    // MARK: - AppBuildInfo surface

    func testAppBuildInfoExposesMemoryLoggingFlag() {
        // The Settings → Technical → Build Info screen reads this exact
        // property. It must mirror the probe's own enablement flag so an
        // on-device tester can verify whether the running build is logging.
        XCTAssertEqual(
            AppBuildInfo.shared.isMemoryLoggingEnabled,
            ImportMemoryProbe.isLoggingEnabled
        )
    }

    /// Regression-Pin (Build-158 Deep-Audit-Fix): vor dem Fix war
    /// `AppBuildInfo.isMemoryLoggingEnabled` ein gespeicherter `let`, der den
    /// Wert beim Process-Start einfror. Wenn ein TestFlight-Tester den
    /// `importMemoryLoggingEnabled`-Toggle umlegte, zeigte die Build-Info
    /// weiterhin "Disabled", während die Toggle-Sektion daneben "Enabled"
    /// auflöste. Dieser Test stellt sicher, dass die Property live mitläuft.
    func testAppBuildInfoMemoryLoggingReflectsLiveSettingsToggle() {
        let suite = "LH2GPXBuildInfoLive-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("Could not create UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        // Lokale Settings-Instanz reicht nicht, weil AppBuildInfo das
        // Singleton liest. Wir setzen direkt den Singleton-Schalter.
        let shared = LocalTimelineTechnicalTestSettings.shared
        let previous = shared.importMemoryLoggingEnabled
        defer { shared.importMemoryLoggingEnabled = previous }

        // Beobachte, dass eine Änderung am Singleton-Setting sich sofort in
        // AppBuildInfo widerspiegelt — vorher fror der Wert ein.
        shared.importMemoryLoggingEnabled = true
        XCTAssertTrue(AppBuildInfo.shared.isMemoryLoggingEnabled,
                      "Build-Info muss Live-Status spiegeln, sobald Toggle an ist")

        // Hinweis: Wenn der Process-Cache (Args/ENV beim Start) bereits true
        // war, kann der nächste Schritt nicht zurück nach false fallen, weil
        // die OR-Semantik korrekt erhalten bleibt. Die obere Assertion
        // dokumentiert den Vorwärtspfad, der den ursprünglichen Bug abdeckt.
    }
}
