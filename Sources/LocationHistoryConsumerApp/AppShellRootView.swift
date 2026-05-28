#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumerAppSupport
import LocationHistoryConsumerDemoSupport
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

struct AppShellRootView: View {
    @State private var session = AppSessionState()
    @State private var isImportingFile = false
    @State private var isShowingOptions = false
    @State private var recentFiles: [RecentFileEntry] = []
    @State private var hasAttemptedAutoRestore = false
    @StateObject private var liveLocation = LiveLocationFeatureModel()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var importUI = LocalTimelineImportUIState()
    @StateObject private var technicalSettings = LocalTimelineTechnicalTestSettings.shared

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    var body: some View {
        Group {
            if session.content != nil {
                #if canImport(UIKit)
                let isIPhone = (UIDevice.current.userInterfaceIdiom == .phone)
                #else
                let isIPhone = false
                #endif

                if isIPhone {
                    if #available(iOS 26.0, *) {
                        LGTabContainerView(
                            session: $session,
                            liveLocation: liveLocation,
                            onOpen: { isImportingFile = true },
                            onLoadDemo: loadBundledDemo,
                            onClear: clearCurrentContent,
                            onOpenOptions: { isShowingOptions = true }
                        )
                        .tint(LH2GPXTheme.LiquidGlass.trackPrimary)
                    } else {
                        AppContentSplitView(
                            session: $session,
                            liveLocation: liveLocation,
                            onOpen: { isImportingFile = true },
                            onLoadDemo: loadBundledDemo,
                            onClear: clearCurrentContent
                        )
                    }
                } else {
                    AppContentSplitView(
                        session: $session,
                        liveLocation: liveLocation,
                        onOpen: { isImportingFile = true },
                        onLoadDemo: loadBundledDemo,
                        onClear: clearCurrentContent
                    )
                }
            } else if let storeSession = session.localTimelineSession {
                // Phase-9B — Store-Session aktiv (feature-flagged); zeigt
                // DayList/DayDetail über den Store. Map/Heatmap/Overview UI
                // gegen den Store bleibt offen (Phase 10).
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
            } else {
                NavigationStack {
                    Group {
                        if session.isLoading {
                            VStack(spacing: 16) {
                                ProgressView(t("Opening location history..."))
                                if importUI.hasObservedSnapshot {
                                    LocalTimelineImportProgressView(
                                        state: importUI,
                                        onCancel: { importUI.cancel() },
                                        localize: t
                                    )
                                }
                            }
                        } else {
                            AppShellWelcomeView(
                                message: session.message,
                                recentFiles: recentFiles,
                                openAction: { isImportingFile = true },
                                reopenRecentAction: reopenRecentFile,
                                removeRecentAction: removeRecentFile,
                                clearRecentHistoryAction: clearRecentHistory,
                                loadDemoAction: loadBundledDemo,
                                clearAction: clearCurrentContent,
                                localize: t,
                                dropAction: handleDroppedURL
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LHLiquidGlassBackground())
                    .navigationTitle("")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                }
            }
        }
        .preproductionBanner(isActive: technicalSettings.localTimelineStoreTestModeEnabled)
        .preferredColorScheme(.dark)
        .environmentObject(preferences)
        .environment(\.locale, preferences.appLocale)
        #if canImport(UniformTypeIdentifiers)
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [
                .json, .zip,
                UTType(filenameExtension: "gpx") ?? .xml,
                UTType(filenameExtension: "tcx") ?? .xml
            ],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        #endif
        .sheet(isPresented: $isShowingOptions) {
            NavigationStack {
                AppOptionsView(preferences: preferences)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(t("Done")) { isShowingOptions = false }
                }
            }
        }
        .onAppear {
            refreshRecentFiles()
            // [LH2GPX_BUILD] header line + `app.start` memory snapshot.
            // Same call site as the wrapper-target ContentView so both
            // app entry points stay in lock-step (LH2GPXAppFlow rule).
            LH2GPXAppFlow.logAppStart()
            installImportCloudUploadHandler()
        }
        .task {
            await attemptAutoRestoreIfNeeded()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )) { _ in
            ImportMemoryProbe.logMemoryWarning()
        }
        #endif
        .onOpenURL { url in
            // Mirrors the wrapper-target ContentView handler so the package
            // app target (used in tests, demo, and the Package.swift build)
            // also routes lh2gpx://live deep links into the Live tab. Was
            // a wiring P1: without this, only the LH2GPXWrapper Xcode build
            // recognised widget deeplinks.
            handleDeepLink(url)
        }
    }
    }

    private func handleDeepLink(_ url: URL) {
        // Delegate to the shared helper so the wrapper target and this
        // package target stay in lock-step. See LH2GPXAppFlow.
        LH2GPXAppFlow.handleDeepLink(url, liveLocation: liveLocation)
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
            LGToolbarActionsLabel()
        }
        .accessibilityLabel(Text(t("Actions")))
    }

    private func loadBundledDemo() {
        ImportBookmarkStore.clear()
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

    private var openButtonTitle: String {
        session.hasLoadedContent ? "Open Another File" : "Open location history file"
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName) ? "Reload Demo" : "Demo Data"
    }

    private func clearCurrentContent() {
        ImportBookmarkStore.clear()
        session.clearContent()
        importUI.reset()
    }

    private func refreshRecentFiles() {
        recentFiles = RecentFilesStore.load()
    }

    /// Verdrahtet den `AppImportCloudUploadBridge`-Handler so, dass eine
    /// importierte Datei nach erfolgreichem Import automatisch via
    /// `CloudKitCloudFileManager` in den privaten iCloud-Bereich
    /// hochgeladen wird — sofern der Nutzer den Toggle aktiviert hat
    /// und der Container/Sync-Gate offen ist.
    private func installImportCloudUploadHandler() {
        AppImportCloudUploadBridge.handler = { url in
            // Gate-Check auf MainActor, weil AppPreferences MainActor-isoliert ist.
            Task { @MainActor in
                guard preferences.iCloudSyncEnabled,
                      preferences.syncCloudFilesEnabled,
                      preferences.autoUploadImportToICloud
                else { return }
                // Wi-Fi-Gate (Best-Effort; auf Linux/Tests trivial true).
                #if canImport(UIKit)
                if preferences.autoUploadImportWifiOnly,
                   LiveTrackCloudNetworkInterfaceProbe.current() != .wifiOrWired {
                    return
                }
                #endif
                #if canImport(CloudKit)
                // `url` ist bereits eine app-owned Staging-URL (siehe
                // `LH2GPXAppFlow.handoffToAutoUpload`) — kein erneutes
                // `copyItem`-Wrapping nötig. Wir räumen den Staging-
                // Ordner erst NACH dem Upload-Abschluss auf, damit ein
                // laufender Upload nicht zerstört wird.
                let manager = CloudKitCloudFileManager()
                defer { AppImportCloudUploadStaging.cleanup(stagedURL: url) }
                do {
                    let candidate = try CloudFileCandidateFactory.makeCandidate(for: url)
                    _ = try await manager.upload(candidate)
                } catch {
                    // SHA-Dedupe gibt CloudFileError.duplicate — harmlos.
                    // Unsupported Type / Validierungsfehler werden geloggt
                    // aber nicht im UI gerendert (Auto-Pfad, kein Banner).
                    #if canImport(OSLog)
                    AppImportCloudUploadLogger.log(error: error, url: url)
                    #endif
                }
                #else
                AppImportCloudUploadStaging.cleanup(stagedURL: url)
                #endif
            }
        }
    }

    private func removeRecentFile(_ entry: RecentFileEntry) {
        RecentFilesStore.remove(id: entry.id)
        refreshRecentFiles()
    }

    private func clearRecentHistory() {
        RecentFilesStore.clear()
        refreshRecentFiles()
    }

    private func reopenRecentFile(_ entry: RecentFileEntry) {
        guard let url = RecentFilesStore.resolveURL(entry: entry) else {
            RecentFilesStore.remove(id: entry.id)
            refreshRecentFiles()
            session.showFailure(
                title: "Recent file unavailable",
                message: "This recent file is no longer accessible. The entry was removed from history.",
                preserveCurrentContent: session.hasLoadedContent
            )
            return
        }

        session.beginLoading()
        Task {
            await loadImportedFile(at: url, source: .recent)
        }
    }

    @MainActor
    private func attemptAutoRestoreIfNeeded() async {
        guard !hasAttemptedAutoRestore else {
            return
        }

        hasAttemptedAutoRestore = true

        guard let url = LH2GPXAppFlow.autoRestoreURLIfEligible(
            autoRestoreEnabled: preferences.autoRestoreLastImport,
            hasLoadedContent: session.hasLoadedContent,
            isLoading: session.isLoading
        ) else {
            return
        }

        session.beginLoading()
        await loadImportedFile(at: url, source: .autoRestore)
    }

    #if canImport(UniformTypeIdentifiers)
    fileprivate func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                return
            }
            session.beginLoading()
            Task { await loadImportedFile(at: url, source: .manual) }
        case let .failure(error):
            if isUserCancelled(error) {
                return
            }
            session.showFailure(
                title: "Unable to open file",
                message: error.localizedDescription,
                preserveCurrentContent: session.hasLoadedContent
            )
        }
    }

    @MainActor
    private func loadImportedFile(at url: URL, source: LH2GPXAppFlow.ImportLoadSource) async {
        // Phase-9A — Package-AppShell nutzt ebenfalls den envelope-Loader,
        // damit beide App-Entry-Points (wrapper + Package) im Lock-Step
        // auf Feature-Flag reagieren. Bei deaktivem Flag identisch zum
        // bisherigen Verhalten.
        // Phase-10A P1-A/B (Weg 2) — frischer Controller pro Import; bei
        // deaktivem Flag bleibt der Sink unbenutzt (Legacy-Pfad emittiert
        // keine Snapshots) und der UI-Hook bleibt unsichtbar.
        let controller = importUI.startNewImport()
        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url,
            source: source,
            importProgress: controller.progressSink,
            importCancellation: controller.cancellation
        )
        let preserve = source == .autoRestore ? false : session.hasLoadedContent
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: outcome,
            to: &session,
            preserveOnFailure: preserve
        )
        switch routing {
        case .legacy, .localTimeline:
            refreshRecentFiles()
        case let .failure(clearBookmark):
            if clearBookmark { ImportBookmarkStore.clear() }
        }
        // Mirror wrapper/LH2GPXWrapper/ContentView.swift:178 — after an
        // import completes, give the home-screen widget a chance to pick up
        // the freshly imported tracks. Gated like the wrapper on
        // `preferences.widgetAutoUpdate`, no-op when WidgetKit is unavailable.
        #if canImport(WidgetKit)
        if preferences.widgetAutoUpdate {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
    #endif
}

private struct AppShellEmptyStateView: View {
    let message: AppUserMessage?
    let recentFiles: [RecentFileEntry]
    let openAction: () -> Void
    let reopenRecentAction: (RecentFileEntry) -> Void
    let removeRecentAction: (RecentFileEntry) -> Void
    let clearRecentHistoryAction: () -> Void
    let loadDemoAction: () -> Void
    let clearAction: () -> Void
    let localize: (String) -> String

    var body: some View {
        ScrollView {
            LHPageScaffold(horizontalPadding: 20, verticalPadding: 28, spacing: 18) {
                LHLiquidGlassHeroMark(
                    title: "LH2GPX",
                    subtitle: localize("Private location history → GPX, KML, CSV, KMZ")
                )
                .accessibilityIdentifier("home.title")

                if let message, message.kind == .error {
                    AppMessageCard(message: message)
                }

                LHLiquidGlassSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "map.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(LH2GPXTheme.LiquidGlass.trackPrimary)
                                .frame(width: 44, height: 44)
                                .background(.thinMaterial, in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(localize("Import File"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                                Text(localize("Processed locally · JSON, ZIP, GPX, TCX"))
                                    .font(.subheadline)
                                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            LHLiquidGlassMetricTile(
                                title: localize("Private"),
                                value: localize("Local"),
                                systemImage: "lock.shield.fill",
                                tint: LH2GPXTheme.LiquidGlass.elevation
                            )
                            LHLiquidGlassMetricTile(
                                title: localize("Formats"),
                                value: "GPX TCX",
                                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                                tint: LH2GPXTheme.LiquidGlass.trackPrimary
                            )
                        }

                        Button(action: openAction) {
                            Label(localize("Import File"), systemImage: "doc.badge.plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 18))
                        .tint(LH2GPXTheme.LiquidGlass.trackPrimary)
                        .accessibilityIdentifier("home.import.primary")
                    }
                }

                GoogleMapsExportHelpInlineAction(
                    titleKey: "Google Maps Export Guide",
                    accessibilityIdentifier: "home.googleHelp"
                )

                LHLiquidGlassSurface(cornerRadius: 22, padding: 14) {
                    HomeActionRow(
                        title: localize("Load Demo"),
                        systemImage: "testtube.2",
                        accessibilityIdentifier: "home.demo",
                        action: loadDemoAction
                    )
                }

                if !recentFiles.isEmpty {
                    RecentFilesView(
                        entries: recentFiles,
                        onOpen: reopenRecentAction,
                        onRemove: { id in
                            if let entry = recentFiles.first(where: { $0.id == id }) {
                                removeRecentAction(entry)
                            }
                        },
                        onClearAll: clearRecentHistoryAction
                    )
                }

                if message?.kind == .error {
                    Button(localize("Clear"), action: clearAction)
                        .buttonStyle(.plain)
                        .foregroundStyle(LH2GPXTheme.primaryBlue)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeLocalPrivacyRow: View {
    let localize: (String) -> String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Color.green)
                .font(.caption)
                .accessibilityHidden(true)
            Text(localize("Processed locally · JSON, ZIP, GPX, TCX"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("home.localNotice")
        .accessibilityLabel(localize("Data processed locally. Supported formats: JSON, ZIP, GPX, TCX"))
    }
}

private struct HomeActionRow: View {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.primaryBlue.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.34))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

extension AppShellRootView {
    /// Train F.4 — Routet eine per Drag&Drop abgelegte File-URL direkt
    /// in den bestehenden Import-Pfad. Spiegelt 1:1 das Erfolgs-Format
    /// des system fileImporter, sodass kein Sonderpfad noetig ist.
    fileprivate func handleDroppedURL(_ url: URL) {
        handleImportResult(.success([url]))
    }
}
#endif
