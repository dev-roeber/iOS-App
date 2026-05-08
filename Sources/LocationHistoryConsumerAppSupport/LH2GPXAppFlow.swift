import Foundation

/// Centralised import / deeplink / auto-restore logic shared between the
/// wrapper-target ContentView and the package-target AppShellRootView.
/// Adding both targets to one helper prevents the recurring bug where a
/// fix only lands on one of the two app entry points (P0-1 / P1-4 both
/// originated as one-sided edits to either ContentView.swift or
/// AppShellRootView.swift). Keep behaviour-shaping logic here so both
/// app shells stay in lock-step by construction.
public enum LH2GPXAppFlow {

    // MARK: - App lifecycle

    /// One-shot launch-time probe: emits a `[LH2GPX_BUILD]` header line
    /// (always) and an `app.start` memory snapshot (when probing enabled).
    /// Called from the wrapper App / shell so the build identity lands in
    /// the device log on the first run before any import work begins.
    @MainActor
    public static func logAppStart(buildInfo: AppBuildInfo = .shared) {
        ImportMemoryProbe.logAppStart(
            marketingVersion: buildInfo.marketingVersion,
            buildNumber: buildInfo.buildNumber,
            gitCommitSHA: buildInfo.gitCommitSHA
        )
    }

    // MARK: - Deep Links

    /// Routes the `lh2gpx://` URL scheme. Returns `true` if the URL was
    /// recognised and handled, `false` otherwise so callers can chain
    /// additional handlers.
    @discardableResult
    @MainActor
    public static func handleDeepLink(
        _ url: URL,
        liveLocation: LiveLocationFeatureModel
    ) -> Bool {
        guard url.scheme == "lh2gpx" else { return false }
        if url.host == "live" {
            liveLocation.navigateToLiveTabRequested = true
            return true
        }
        return false
    }

    // MARK: - Import / Restore

    /// Where an import attempt originated. Drives both the user-facing
    /// failure copy and whether the loader runs in auto-restore mode
    /// (which skips very large Google Timeline files).
    public enum ImportLoadSource: Sendable {
        case manual
        case recent
        case autoRestore
    }

    /// Outcome surfaced back to the caller so each app shell can update
    /// its own `AppSessionState` / progress engine without the helper
    /// having to know about either type directly.
    public enum ImportOutcome {
        case success(AppSessionContent)
        case failure(title: String, message: String, clearBookmark: Bool)
    }

    /// Loads an imported file using the shared `AppContentLoader`,
    /// honouring security-scoped resource access, persisting the
    /// bookmark/recent entry on success, and translating loader errors
    /// into user-facing copy that matches the import source.
    ///
    /// `onPhase` is wired through for *every* source — including
    /// `.autoRestore` — so the loading screen reflects progress even
    /// when the import was kicked off automatically at launch.
    public static func loadImportedFile(
        at url: URL,
        source: ImportLoadSource,
        onPhase: (@Sendable (ImportPhase) -> Void)? = nil
    ) async -> ImportOutcome {
        // Security-scoped resource APIs only exist on Darwin (UIKit/AppKit).
        // On Linux (headless test runs) we treat any file URL as already
        // accessible — there is no sandbox to opt into.
        #if canImport(UIKit) || canImport(AppKit)
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #endif

        do {
            let content = try await AppContentLoader.loadImportedContent(
                from: url,
                autoRestoreMode: source == .autoRestore,
                onPhase: onPhase
            )
            AppImportStateBridge.rememberImportedFile(url)
            return .success(content)
        } catch {
            // Auto-restore skipped a large Google Timeline file — keep
            // the bookmark so the user can still re-open manually, and
            // surface the dedicated copy regardless of source.
            if let loaderError = error as? AppContentLoaderError,
               case .autoRestoreSkippedLargeFile = loaderError {
                return .failure(
                    title: loaderError.userFacingTitle,
                    message: loaderError.localizedDescription,
                    clearBookmark: false
                )
            }

            switch source {
            case .manual:
                let title = (error as? AppContentLoaderError)?.userFacingTitle
                    ?? "Unable to open file"
                return .failure(
                    title: title,
                    message: error.localizedDescription,
                    clearBookmark: false
                )
            case .recent:
                return .failure(
                    title: "Unable to reopen recent file",
                    message: "Import the file again if it was moved, deleted or changed outside the app.",
                    clearBookmark: false
                )
            case .autoRestore:
                let title = (error as? AppContentLoaderError)?.userFacingTitle
                    ?? "Unable to restore previous import"
                return .failure(
                    title: title,
                    message: error.localizedDescription,
                    clearBookmark: true
                )
            }
        }
    }

    /// Returns the URL to auto-restore at launch if (a) auto-restore
    /// is enabled, (b) no content is currently loaded, and (c) a
    /// previous bookmark exists. Returns `nil` otherwise so callers can
    /// short-circuit without having to inspect session state.
    @MainActor
    public static func autoRestoreURLIfEligible(
        autoRestoreEnabled: Bool,
        hasLoadedContent: Bool,
        isLoading: Bool
    ) -> URL? {
        guard !hasLoadedContent, !isLoading else { return nil }
        return AppImportStateBridge.restoreLastImportIfEnabled(
            autoRestoreEnabled: autoRestoreEnabled
        )
    }
}
