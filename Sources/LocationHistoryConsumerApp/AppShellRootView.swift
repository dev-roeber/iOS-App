#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumerAppSupport
import LocationHistoryConsumerDemoSupport
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct AppShellRootView: View {
    @State private var session = AppSessionState()
    @State private var isImportingFile = false
    @State private var isShowingOptions = false
    @State private var recentFiles: [RecentFileEntry] = []
    @State private var hasAttemptedAutoRestore = false
    @StateObject private var liveLocation = LiveLocationFeatureModel()
    @StateObject private var preferences = AppPreferences()

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
                    Group {
                        if session.isLoading {
                            ProgressView(t("Opening location history..."))
                        } else {
                            AppShellEmptyStateView(
                                message: session.message,
                                recentFiles: recentFiles,
                                openAction: { isImportingFile = true },
                                reopenRecentAction: reopenRecentFile,
                                removeRecentAction: removeRecentFile,
                                clearRecentHistoryAction: clearRecentHistory,
                                loadDemoAction: loadBundledDemo,
                                clearAction: clearCurrentContent,
                                localize: t
                            )
                        }
                    }
                    .navigationTitle("LH2GPX")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                }
            }
        }
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
        }
        .task {
            await attemptAutoRestoreIfNeeded()
        }
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
    }

    private func refreshRecentFiles() {
        recentFiles = RecentFilesStore.load()
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

        guard !session.hasLoadedContent,
              let url = AppImportStateBridge.restoreLastImportIfEnabled(
                  autoRestoreEnabled: preferences.autoRestoreLastImport
              ) else {
            return
        }

        session.beginLoading()
        await loadImportedFile(at: url, source: .autoRestore)
    }

    #if canImport(UniformTypeIdentifiers)
    private enum ImportLoadSource {
        case manual
        case recent
        case autoRestore
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
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
    private func loadImportedFile(at url: URL, source: ImportLoadSource) async {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let content = try await AppContentLoader.loadImportedContent(from: url)
            AppImportStateBridge.rememberImportedFile(url)
            refreshRecentFiles()
            session.show(content: content)
        } catch {
            let title: String
            let message: String

            switch source {
            case .manual:
                title = (error as? AppContentLoaderError)?.userFacingTitle ?? "Unable to open file"
                message = error.localizedDescription
            case .recent:
                title = "Unable to reopen recent file"
                message = "Import the file again if it was moved, deleted or changed outside the app."
            case .autoRestore:
                title = "Unable to restore last import"
                message = "The last imported file could not be reopened automatically. Open a file manually to continue."
            }

            session.showFailure(
                title: title,
                message: message,
                preserveCurrentContent: session.hasLoadedContent
            )
        }
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(localize("Import your location history"))
                    .font(.title2.weight(.semibold))
                Text(localize("Open an LH2GPX app_export.json or .zip from the LocationHistory2GPX tool — or a Google Timeline location-history.json or .zip from Google Takeout."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let message, message.kind == .error {
                AppMessageCard(message: message)
            }

            if !recentFiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(localize("Recent Files"))
                            .font(.headline)
                        Spacer()
                        Button(localize("Clear History"), action: clearRecentHistoryAction)
                            .font(.caption.weight(.semibold))
                    }

                    VStack(spacing: 10) {
                        ForEach(recentFiles) { entry in
                            recentFileRow(entry)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            GoogleMapsExportHelpInlineAction()

            VStack(spacing: 10) {
                Button(action: openAction) {
                    Label(localize("Open location history file"), systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Button(action: loadDemoAction) {
                    Label(localize("Load Demo Data"), systemImage: "testtube.2")
                }
                .buttonStyle(.bordered)
                if message?.kind == .error {
                    Button(action: clearAction) {
                        Label(localize("Clear"), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    @ViewBuilder
    private func recentFileRow(_ entry: RecentFileEntry) -> some View {
        let isAvailable = RecentFilesStore.isAvailable(entry: entry)
        let iconColor: Color = isAvailable ? .accentColor : .orange

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isAvailable ? "clock.arrow.circlepath" : "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(recentFileMetadata(entry: entry, isAvailable: isAvailable))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAvailable {
                Button(localize("Open Again")) {
                    reopenRecentAction(entry)
                }
                .font(.caption.weight(.semibold))
            } else {
                Text(localize("Unavailable"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Button {
                removeRecentAction(entry)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localize("Remove Entry"))
        }
        .padding(.vertical, 2)
    }

    private func recentFileMetadata(entry: RecentFileEntry, isAvailable: Bool) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let openedText = formatter.localizedString(for: entry.lastOpenedAt, relativeTo: Date())
        let availabilityText = isAvailable ? localize("Available") : localize("Unavailable")
        return "\(availabilityText) · \(localize("Opened")) \(openedText)"
    }
}
#endif
