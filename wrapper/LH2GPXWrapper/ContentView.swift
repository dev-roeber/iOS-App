import SwiftUI
import UIKit
import WidgetKit
import LocationHistoryConsumerAppSupport
import LocationHistoryConsumerDemoSupport
import UniformTypeIdentifiers

struct ContentView: View {
    private enum LaunchArgument {
        static let uiTesting = "LH2GPX_UI_TESTING"
        static let resetPersistence = "LH2GPX_RESET_PERSISTENCE"
        static let dynamicIslandDisplayPrefix = "LH2GPX_DYNAMIC_ISLAND_DISPLAY="
        static let uploadEnabledPrefix = "LH2GPX_UPLOAD_ENABLED="
        static let uploadURLPrefix = "LH2GPX_UPLOAD_URL="
        static let uploadBatchPrefix = "LH2GPX_UPLOAD_BATCH="
        /// UI-Testing-only: when set together with `LH2GPX_UI_TESTING`,
        /// the app generates a synthetic Google-Timeline-style JSON of
        /// approximately the requested byte count in the app's temp
        /// directory on launch, then drives the production import path
        /// against that file. Lets the LH2GPXWrapperUITests reproduce
        /// the 46-MiB Google-Timeline import on real hardware without
        /// shipping a multi-MiB fixture in the app bundle.
        ///
        /// Production behaviour is unaffected: the helper bails out
        /// unless BOTH `LH2GPX_UI_TESTING` and this prefix are present.
        static let uiLargeImportBytesPrefix = "LH2GPX_UI_LARGE_IMPORT_BYTES="
    }

    @State private var session = AppSessionState()
    @State private var isImportingFile = false
    @State private var isShowingOptions = false
    @State private var hasPreparedLaunchState = false
    @StateObject private var liveLocation = LiveLocationFeatureModel()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var loadingProgress = LoadingProgressEngine()
    @StateObject private var importUI = LocalTimelineImportUIState()
    @StateObject private var technicalSettings = LocalTimelineTechnicalTestSettings.shared

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    /// User-facing import phase string. Falls back to the legacy "Opening …"
    /// label when no phase is reported yet (very fast imports, fixture loads).
    private var loadingPhaseLabel: String {
        guard let phase = loadingProgress.phase else {
            return t("Opening location history...")
        }
        switch phase {
        case .reading:  return t("Reading file…")
        case .parsing:  return t("Parsing entries…")
        case .building: return t("Building model…")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if technicalSettings.localTimelineStoreTestModeEnabled {
                LocalTimelineTestModeBanner()
            }
        Group {
            if session.content != nil {
                AppContentSplitView(
                    session: $session,
                    liveLocation: liveLocation,
                    onOpen: { isImportingFile = true },
                    onLoadDemo: loadBundledDemo,
                    onClear: clearCurrentContent
                )
            } else if let storeSession = session.localTimelineSession {
                // Phase-9B — Store-Session aktiv (feature-flagged). Zeigt
                // Metadaten + DayList/DayDetail + Delete-Button.
                // Map/Heatmap/Overview UI gegen den Store bleibt offen.
                NavigationStack {
                    LocalTimelineSessionLandingView(
                        session: storeSession,
                        onClear: clearCurrentContent,
                        deletionPresentation: LH2GPXAppFlow.makeProductionDeletionPresentation(),
                        dayBrowser: LH2GPXAppFlow.makeProductionDayBrowserSource(for: storeSession),
                        selectedDayId: session.selectedLocalTimelineDayId,
                        onSelectDay: { session.selectLocalTimelineDay($0) },
                        dayMapSource: LH2GPXAppFlow.makeProductionDayMapSource(for: storeSession)
                    )
                    .navigationTitle("LH2GPX")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) { actionsMenu }
                    }
                }
                .preferredColorScheme(.dark)
            } else {
                NavigationStack {
                    ZStack {
                        LH2GPXLoadingBackground(progress: loadingProgress.progress) {
                            homeBackground
                        }
                        .ignoresSafeArea()
                        Group {
                            if session.isLoading {
                                VStack(spacing: 16) {
                                    ProgressView(loadingPhaseLabel)
                                        .tint(.white)
                                        .foregroundStyle(.white)
                                    if importUI.hasObservedSnapshot {
                                        LocalTimelineImportProgressView(
                                            state: importUI,
                                            onCancel: { importUI.cancel() }
                                        )
                                    }
                                }
                            } else {
                                emptyStateView
                            }
                        }
                    }
                    .navigationTitle("LH2GPX")
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                }
                .preferredColorScheme(.dark)
                .onChange(of: session.isLoading) { _, isLoading in
                    if isLoading {
                        loadingProgress.start()
                    } else if session.content != nil {
                        loadingProgress.complete()
                    } else {
                        loadingProgress.cancel()
                    }
                }
            }
        }
        }
        .environmentObject(preferences)
        .environment(\.locale, preferences.appLocale)
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.json, .zip, .gpx, .tcx],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .sheet(isPresented: $isShowingOptions) {
            NavigationStack {
                AppOptionsView(preferences: preferences)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(t("Done")) { isShowingOptions = false }
                        }
                    }
            }
        }
        .onReceive(liveLocation.$recordedTracks) { _ in
            guard preferences.widgetAutoUpdate else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { url in
            // Handle deep links from Widget (lh2gpx://live) and other sources
            handleDeepLink(url)
        }
        .task {
            await prepareLaunchStateIfNeeded()
            restoreBookmarkedFile()
        }
        .onAppear {
            // Emit one [LH2GPX_BUILD] header line + an `app.start` memory
            // snapshot the first time the shell renders. Idempotent: the
            // probe itself short-circuits when already disabled and
            // logAppStart is harmless to call repeatedly.
            LH2GPXAppFlow.logAppStart()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )) { _ in
            ImportMemoryProbe.logMemoryWarning()
        }
    }

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            Button {
                isImportingFile = true
            } label: {
                Label(t(openButtonTitle), systemImage: "doc.badge.plus")
            }
            Button(action: loadBundledDemo) {
                Label(t(demoButtonTitle), systemImage: "testtube.2")
            }
            Divider()
            Button {
                isShowingOptions = true
            } label: {
                Label(t("Options"), systemImage: "slider.horizontal.3")
            }
            if session.hasLoadedContent || session.message?.kind == .error {
                Divider()
                Button(role: .destructive, action: clearCurrentContent) {
                    Label(t("Clear"), systemImage: "xmark.circle")
                }
            }
        } label: {
            Label(t("Actions"), systemImage: "ellipsis.circle")
        }
    }

    private var homeBackground: some View {
        ZStack {
            // Base solid colour so any letterboxing on tall iPads still
            // matches the artwork's deep-blue palette instead of system grey.
            Color(red: 0.02, green: 0.04, blue: 0.10)
            Image("HomeBackground")
                .resizable()
                .scaledToFill()
                // Soft vertical legibility ramp: darker at top so the
                // navigation title reads cleanly, slightly darker at bottom
                // so the privacy chip and buttons keep their contrast.
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.55),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.45), radius: 8, y: 2)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(t("Import your location history"))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text(t("Open an app_export.json or .zip from the LocationHistory2GPX tool — or a Google Timeline location-history.json or .zip from Google Takeout."))
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
            .shadow(color: Color.black.opacity(0.45), radius: 8, y: 2)

            if let message = session.message, message.kind == .error {
                AppMessageCard(message: message)
            }

            GoogleMapsExportHelpInlineAction()

            VStack(spacing: 10) {
                Button {
                    isImportingFile = true
                } label: {
                    Label(t("Open location history file"), systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Button(action: loadBundledDemo) {
                    Label(t("Load Demo Data"), systemImage: "testtube.2")
                }
                .buttonStyle(.bordered)
                if session.message?.kind == .error {
                    Button(action: clearCurrentContent) {
                        Label(t("Clear"), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Privacy assurance: all processing happens on-device.
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.green)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(t("Processed locally · JSON, ZIP, GPX, TCX"))
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("home.localNotice")
            .accessibilityLabel(t("Data processed locally. Supported formats: JSON, ZIP, GPX, TCX"))

            Spacer()
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var openButtonTitle: String {
        session.hasLoadedContent ? "Open Another File" : "Open location history file"
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
            ? "Reload Demo" : "Demo Data"
    }

    private func loadBundledDemo() {
        session.beginLoading()
        do {
            session.show(content: try DemoDataLoader.loadDefaultContent())
        } catch {
            session.showFailure(
                title: "Unable to load demo data",
                message: error.localizedDescription,
                preserveCurrentContent: session.hasLoadedContent
            )
        }
    }

    private func clearCurrentContent() {
        ImportBookmarkStore.clear()
        session.clearContent()
        importUI.reset()
    }

    @MainActor
    private func prepareLaunchStateIfNeeded() async {
        guard !hasPreparedLaunchState else { return }
        hasPreparedLaunchState = true

        guard launchArguments.contains(LaunchArgument.uiTesting),
              launchArguments.contains(LaunchArgument.resetPersistence) else {
            return
        }

        ImportBookmarkStore.clear()
        RecentFilesStore.clear()
        preferences.reset()
        session.clearContent()
        applyUITestingOverrides()
        if let bytes = uiLargeImportBytes() {
            await runUITestingLargeImport(targetBytes: bytes)
        }
    }

    /// UI-Testing-only helper. Generates a synthetic Google-Timeline-style
    /// JSON of approximately `targetBytes` bytes in the app temp directory
    /// and drives the production import path through it.
    ///
    /// Gated behind both `LH2GPX_UI_TESTING` and `LH2GPX_UI_LARGE_IMPORT_BYTES=`.
    /// No production code path reaches this function. Synthesised file is
    /// deleted after the import completes.
    @MainActor
    private func runUITestingLargeImport(targetBytes: Int) async {
        guard targetBytes > 0 else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lh2gpx-uitest-large-import-\(UUID().uuidString.prefix(8)).json")
        do {
            try Self.writeSyntheticGoogleTimelineJSON(to: tmp, targetBytes: targetBytes)
        } catch {
            session.showFailure(
                title: "UITesting synthetic-import generator failed",
                message: error.localizedDescription,
                preserveCurrentContent: false
            )
            return
        }
        session.beginLoading()
        await runImport(at: tmp, source: .manual)
        try? FileManager.default.removeItem(at: tmp)
    }

    /// Writes a Google-Timeline-style JSON array of approximately
    /// `targetBytes` bytes to `url`. Each entry is a small `visit`
    /// record so the streaming parser exercises the same code path
    /// as a real Google Timeline export without spending CPU on
    /// per-point coordinate decoding. Pure file I/O; no app state
    /// is touched.
    fileprivate static func writeSyntheticGoogleTimelineJSON(to url: URL, targetBytes: Int) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            throw NSError(
                domain: "LH2GPXUITestingLargeImport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not open \(url.lastPathComponent) for writing"]
            )
        }
        defer { try? handle.close() }
        try handle.write(contentsOf: Data("[".utf8))
        var written = 1
        var index = 0
        // Anchor at a stable midnight so generated timestamps look
        // realistic and the timeline parser does not reject anything
        // as out of range.
        let baseEpoch: TimeInterval = 1_714_521_600  // 2024-05-01T00:00:00Z
        while written < targetBytes {
            let lat = 52.5 + Double(index % 1_000) * 0.0001
            let lon = 13.4 + Double(index % 500) * 0.0002
            let startISO = Self.iso8601(from: baseEpoch + Double(index) * 60)
            let endISO   = Self.iso8601(from: baseEpoch + Double(index) * 60 + 30)
            let separator = (index == 0) ? "" : ",\n"
            let entry = "\(separator){\"startTime\":\"\(startISO)\",\"endTime\":\"\(endISO)\",\"visit\":{\"topCandidate\":{\"semanticType\":\"INFERRED_HOME\",\"placeLocation\":\"geo:\(lat),\(lon)\"}}}"
            let chunk = Data(entry.utf8)
            try handle.write(contentsOf: chunk)
            written += chunk.count
            index += 1
        }
        try handle.write(contentsOf: Data("\n]".utf8))
    }

    private static func iso8601(from epoch: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: epoch)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func uiLargeImportBytes() -> Int? {
        guard let raw = launchArgumentValue(prefix: LaunchArgument.uiLargeImportBytesPrefix),
              let value = Int(raw), value > 0 else { return nil }
        return value
    }

    private func restoreBookmarkedFile() {
        guard let url = LH2GPXAppFlow.autoRestoreURLIfEligible(
            autoRestoreEnabled: preferences.autoRestoreLastImport,
            hasLoadedContent: session.hasLoadedContent,
            isLoading: session.isLoading
        ) else { return }
        session.beginLoading()
        Task {
            // Auto-restore now propagates onPhase like the manual import
            // path so the loading screen reflects progress even when the
            // import was kicked off automatically at launch.
            await runImport(at: url, source: .autoRestore)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first, !session.isLoading else { return }
            session.beginLoading()
            Task { await runImport(at: url, source: .manual) }
        case let .failure(error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return
            }
            session.showFailure(
                title: "Unable to open file",
                message: error.localizedDescription,
                preserveCurrentContent: session.hasLoadedContent
            )
        }
    }

    /// Thin wrapper around the shared helper. See LH2GPXAppFlow for the
    /// security-scope / loader / failure-mapping logic shared with the
    /// package-target AppShellRootView. onPhase is wired through for
    /// every source so auto-restore drives the loading screen too.
    private func runImport(at url: URL, source: LH2GPXAppFlow.ImportLoadSource) async {
        // Phase-9A — Wrapper nutzt den feature-flagged Envelope-Loader.
        // Bei deaktivem Flag liefert er byte-identisch `.legacy(content)`,
        // bei aktivem Flag gegen Google-Timeline-JSON/-ZIP eine
        // `.localTimeline(session)` ohne AppExport-Materialisierung.
        // Phase-10A P1-A/B (Weg 2) — frischer ImportController für jeden
        // Import; bei deaktivem Flag bleibt der Sink unbenutzt.
        let controller = await MainActor.run { importUI.startNewImport() }
        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url,
            source: source,
            onPhase: { phase in
                Task { @MainActor in loadingProgress.setPhase(phase) }
            },
            importProgress: controller.progressSink,
            importCancellation: controller.cancellation
        )
        await MainActor.run {
            let preserve = source == .autoRestore
                ? false
                : session.hasLoadedContent
            let routing = LH2GPXAppFlow.apply(
                envelopeOutcome: outcome,
                to: &session,
                preserveOnFailure: preserve
            )
            if case let .failure(clearBookmark) = routing, clearBookmark {
                ImportBookmarkStore.clear()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Delegate to the shared helper so this wrapper target and the
        // package-target AppShellRootView stay in lock-step.
        LH2GPXAppFlow.handleDeepLink(url, liveLocation: liveLocation)
    }

    private var launchArguments: Set<String> {
        Set(ProcessInfo.processInfo.arguments)
    }

    private func applyUITestingOverrides() {
        if let rawValue = launchArgumentValue(prefix: LaunchArgument.dynamicIslandDisplayPrefix),
           let value = DynamicIslandCompactDisplay(rawValue: rawValue) {
            preferences.dynamicIslandCompactDisplay = value
        }

        if let rawValue = launchArgumentValue(prefix: LaunchArgument.uploadEnabledPrefix) {
            preferences.sendsLiveLocationToServer = rawValue == "1" || rawValue.lowercased() == "true"
        }

        if let rawValue = launchArgumentValue(prefix: LaunchArgument.uploadURLPrefix) {
            preferences.liveLocationServerUploadURLString = rawValue
        }

        if let rawValue = launchArgumentValue(prefix: LaunchArgument.uploadBatchPrefix),
           let value = AppLiveTrackingUploadBatchPreference(rawValue: rawValue) {
            preferences.liveTrackingUploadBatch = value
        }
    }

    private func launchArgumentValue(prefix: String) -> String? {
        ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }).map {
            String($0.dropFirst(prefix.count))
        }
    }
}
