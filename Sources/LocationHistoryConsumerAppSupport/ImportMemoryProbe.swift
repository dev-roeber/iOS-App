import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Diagnostic-only memory probe used to localize the post-streaming peak
/// that triggered Jetsam on iPhone 15 Pro Max during the 46 MB Google Timeline
/// import (2026-05-07 hardware fails, 1./2./3. reproduction). Activated by
/// setting `LH2GPX_IMPORT_MEMORY_LOG=1` either as a launch argument or as an
/// environment variable on the device run scheme. Each call emits a single
/// line tagged `[LH2GPX_MEMORY]` so it is trivial to grep out of the Xcode
/// Console.
///
/// The probe is best-effort and side-effect free: when disabled it is a
/// no-op; when enabled it never throws and never blocks the import path. We
/// deliberately avoid private APIs and use only `mach_task_self` /
/// `task_info(TASK_VM_INFO)` counters — gated on `canImport(Darwin)` so the
/// Linux SwiftPM test harness still builds.
public enum ImportMemoryProbe {
    public static let launchArgumentKey = "LH2GPX_IMPORT_MEMORY_LOG"

    /// Public, read-only enablement flag. Surfaced through `AppBuildInfo` and
    /// the Settings → Technical → Build Info screen so a tester can verify
    /// at-a-glance whether the running build is actually emitting probes.
    ///
    /// Build-158 — der Probe respektiert ab jetzt zusätzlich den
    /// `LocalTimelineTechnicalTestSettings.shared.importMemoryLoggingEnabled`
    /// Toggle (UserDefaults-Bool, default OFF). Args/ENV bleiben primärer,
    /// schnellster Pfad (Cache); das Setting wird pro Aufruf nachgelesen,
    /// damit ein TestFlight-Tester ohne Relaunch zwischen Aus und An
    /// wechseln kann.
    public static var isLoggingEnabled: Bool {
        if processCachedFlag { return true }
        return LocalTimelineTechnicalTestSettings.shared.importMemoryLoggingEnabled
    }

    /// Cached enablement flag — read once at first probe so we don't pay the
    /// argument-parsing cost per call. Both ProcessInfo paths are honoured:
    ///   - environment: `LH2GPX_IMPORT_MEMORY_LOG=1`
    ///   - launch arguments: `LH2GPX_IMPORT_MEMORY_LOG`,
    ///     `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`,
    ///     `LH2GPX_IMPORT_MEMORY_LOG=1`
    private static let processCachedFlag: Bool = isEnabledForEnvironment(
        ProcessInfo.processInfo.environment,
        arguments: ProcessInfo.processInfo.arguments
    )

    /// Pure activation rule — exposed so a Linux unit test can verify both
    /// paths (env + args) without driving a real `ProcessInfo` instance.
    public static func isEnabledForEnvironment(
        _ environment: [String: String],
        arguments: [String]
    ) -> Bool {
        if environment[launchArgumentKey] == "1" { return true }
        for arg in arguments {
            if arg == launchArgumentKey
                || arg == "-\(launchArgumentKey)"
                || arg == "--\(launchArgumentKey)"
                || arg == "\(launchArgumentKey)=1" {
                return true
            }
        }
        return false
    }

    /// Build-158 — Pure activation rule mit zusätzlichem Settings-Pfad.
    /// Args/ENV haben Vorrang; das Setting aktiviert nur zusätzlich.
    public static func isEnabledForEnvironment(
        _ environment: [String: String],
        arguments: [String],
        settings: LocalTimelineTechnicalTestSettings
    ) -> Bool {
        if isEnabledForEnvironment(environment, arguments: arguments) { return true }
        return settings.importMemoryLoggingEnabled
    }

    /// Logs `[LH2GPX_MEMORY] <phase> footprint=<MB> resident=<MB>` if the
    /// launch argument is set. `phase` should be a short, grep-friendly label.
    public static func log(_ phase: @autoclosure () -> String) {
        guard isLoggingEnabled else { return }
        let label = phase()
        let snapshot = currentFootprintMB()
        let footprint = snapshot.footprintMB.map { String(format: "%.1f", $0) } ?? "n/a"
        let resident = snapshot.residentMB.map { String(format: "%.1f", $0) } ?? "n/a"
        let line = "[LH2GPX_MEMORY] \(label) footprint=\(footprint)MB resident=\(resident)MB"
        // `print` is sufficient — Xcode Console captures stdout; we don't
        // want to depend on os.Logger here so the probe also works in the
        // SwiftPM test harness on Linux/macOS.
        print(line)
    }

    /// Throttled probe: emits `[LH2GPX_MEMORY] <phase>=<counter>` every
    /// `every`-th call. The counter is the caller's responsibility so each
    /// probe site can keep its own monotonic counter without forcing a
    /// shared global. Disabled-state short-circuits before any string work.
    public static func logEvery(
        _ phase: String,
        counter: Int,
        every: Int
    ) {
        guard isLoggingEnabled else { return }
        guard every > 0, counter > 0, counter % every == 0 else { return }
        log("\(phase)=\(counter)")
    }

    /// Emits the build-identity header line. Called once at app launch so the
    /// Xcode Console makes it obvious which build the tester is looking at —
    /// the 2026-05-07 hardware re-fail wasted half a session because nobody
    /// could verify whether the device build actually contained the fix.
    /// The line is emitted even when the probe is otherwise disabled so the
    /// build identity is always grep-able from production logs.
    public static func logAppStart(
        marketingVersion: String,
        buildNumber: String,
        gitCommitSHA: String?
    ) {
        let sha = gitCommitSHA ?? "unknown"
        let memFlag = isLoggingEnabled ? "enabled" : "disabled"
        // Always emitted (no `guard isEnabled`) so the build identity lands
        // in every log even when memory probing is disabled.
        print("[LH2GPX_BUILD] app.start version=\(marketingVersion) build=\(buildNumber) sha=\(sha) memoryLogging=\(memFlag)")
        // Memory snapshot at start — only when probing enabled.
        log("app.start")
    }

    /// Fired from the iOS-side `UIApplication.didReceiveMemoryWarningNotification`
    /// observer. Keeps the call out of the AppSupport package so the package
    /// itself stays free of UIKit imports. Caller wires up the observer.
    public static func logMemoryWarning() {
        log("app.didReceiveMemoryWarning")
    }

    public struct Snapshot {
        public let footprintMB: Double?
        public let residentMB: Double?
    }

    public static func currentFootprintMB() -> Snapshot {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let footprint = Double(info.phys_footprint) / 1_048_576.0
            let resident = Double(info.resident_size) / 1_048_576.0
            return Snapshot(footprintMB: footprint, residentMB: resident)
        }
        return Snapshot(footprintMB: nil, residentMB: nil)
        #else
        return Snapshot(footprintMB: nil, residentMB: nil)
        #endif
    }
}
