import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Diagnostic-only memory probe used to localize the post-streaming peak
/// that triggered Jetsam on iPhone 15 Pro Max during the 46 MB Google Timeline
/// import (2026-05-07 hardware fail). Activated by setting the launch
/// argument `LH2GPX_IMPORT_MEMORY_LOG=1` on the device run scheme. Each call
/// emits a single line tagged `[LH2GPX_MEMORY]` so it is trivial to grep
/// out of the Xcode Console.
///
/// The probe is best-effort and side-effect free: when disabled it is a
/// no-op; when enabled it never throws and never blocks the import path. We
/// deliberately avoid private APIs and use only `mach_task_self` /
/// `task_info(MACH_TASK_BASIC_INFO)`-equivalent counters.
public enum ImportMemoryProbe {
    public static let launchArgumentKey = "LH2GPX_IMPORT_MEMORY_LOG"

    /// Cached enablement flag — read once at first probe so we don't pay the
    /// argument-parsing cost per call.
    private static let isEnabled: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env[launchArgumentKey] == "1" { return true }
        return ProcessInfo.processInfo.arguments.contains { arg in
            arg == launchArgumentKey
                || arg == "-\(launchArgumentKey)"
                || arg == "--\(launchArgumentKey)"
                || arg == "\(launchArgumentKey)=1"
        }
    }()

    /// Logs `[LH2GPX_MEMORY] <phase> footprint=<MB> resident=<MB>` if the
    /// launch argument is set. `phase` should be a short, grep-friendly label.
    public static func log(_ phase: @autoclosure () -> String) {
        guard isEnabled else { return }
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
