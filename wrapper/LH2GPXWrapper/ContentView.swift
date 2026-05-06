import SwiftUI
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
    }

    @State private var session = AppSessionState()
    @State private var isImportingFile = false
    @State private var isShowingOptions = false
    @State private var hasPreparedLaunchState = false
    @StateObject private var liveLocation = LiveLocationFeatureModel()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var loadingProgress = LoadingProgressEngine()

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    var body: some View {
        Group {
            if session.content != nil {
                AppContentSplitView(
                    session: $session,
                    liveLocation: liveLocation,
                    onOpen: { isImportingFile = true },
                    onLoadDemo: loadBundledDemo,
                    onClear: clearCurrentContent
                )
            } else {
                NavigationStack {
                    ZStack {
                        LH2GPXLoadingBackground(progress: loadingProgress.progress) {
                            homeBackground
                        }
                        .ignoresSafeArea()
                        Group {
                            if session.isLoading {
                                ProgressView(t("Opening location history..."))
                                    .tint(.white)
                                    .foregroundStyle(.white)
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
                .onChange(of: session.isLoading) { isLoading in
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
    }

    private func restoreBookmarkedFile() {
        guard !session.hasLoadedContent, !session.isLoading else { return }
        guard let url = AppImportStateBridge.restoreLastImportIfEnabled(
            autoRestoreEnabled: preferences.autoRestoreLastImport
        ) else { return }
        session.beginLoading()
        Task {
            let accessedSecurityScope = url.startAccessingSecurityScopedResource()
            do {
                let content = try await AppContentLoader.loadImportedContent(from: url)
                if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
                session.show(content: content)
            } catch {
                if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
                ImportBookmarkStore.clear()
                session.showFailure(
                    title: "Unable to restore previous import",
                    message: error.localizedDescription,
                    preserveCurrentContent: false
                )
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first, !session.isLoading else { return }
            session.beginLoading()
            loadImportedFile(at: url)
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

    private func loadImportedFile(at url: URL) {
        Task {
            let accessedSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let content = try await AppContentLoader.loadImportedContent(from: url)
                ImportBookmarkStore.save(url: url)
                _ = RecentFilesStore.add(url: url)
                session.show(content: content)
            } catch {
                session.showFailure(
                    title: (error as? AppContentLoaderError)?.userFacingTitle ?? "Unable to open file",
                    message: error.localizedDescription,
                    preserveCurrentContent: session.hasLoadedContent
                )
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "lh2gpx" else { return }
        // lh2gpx://live → navigate to Live tab if content is loaded
        if url.host == "live" {
            liveLocation.navigateToLiveTabRequested = true
        }
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
