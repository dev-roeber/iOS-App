import Foundation

/// Surfaces the running build's identity (Marketing version, Build number,
/// optional Git commit SHA) so testers can verify on the device which build
/// is actually executing. Was added after the 2026-05-07 hardware Jetsam
/// re-fail where it was unclear whether the autoreleasepool fix in
/// `cd77f97` was actually present in the build under test.
public struct AppBuildInfo {
    public static let shared = AppBuildInfo()

    public let marketingVersion: String
    public let buildNumber: String
    public let gitCommitSHA: String?

    public init(bundle: Bundle = .main) {
        let info = bundle.infoDictionary
        self.marketingVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        self.buildNumber = (info?["CFBundleVersion"] as? String) ?? "?"
        // Two injection paths supported, in priority order:
        //   1. Info.plist key `GitCommitSHA` written by a build-phase script.
        //   2. Compile-time `LH2GPX_GIT_SHA` define passed via SWIFT_ACTIVE_COMPILATION_CONDITIONS.
        if let plistSHA = info?["GitCommitSHA"] as? String, !plistSHA.isEmpty, plistSHA != "$(GIT_COMMIT_SHA)" {
            self.gitCommitSHA = plistSHA
        } else {
            self.gitCommitSHA = nil
        }
    }

    /// Compact one-line description suitable for log lines or compact UI.
    public var displayLine: String {
        if let sha = gitCommitSHA {
            return "v\(marketingVersion) (\(buildNumber)) · \(sha)"
        }
        return "v\(marketingVersion) (\(buildNumber))"
    }
}
