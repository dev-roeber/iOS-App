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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
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
            let content = try await AppContentLoader.loadImportedContent(
                from: url,
                autoRestoreMode: source == .autoRestore
            )
            AppImportStateBridge.rememberImportedFile(url)
            refreshRecentFiles()
            session.show(content: content)
        } catch {
            let title: String
            let message: String

            // Auto-restore skipped a large Google Timeline file — surface the
            // dedicated user-facing copy regardless of source so the message
            // is unambiguous.
            if let loaderError = error as? AppContentLoaderError,
               case .autoRestoreSkippedLargeFile = loaderError {
                session.showFailure(
                    title: loaderError.userFacingTitle,
                    message: loaderError.localizedDescription,
                    preserveCurrentContent: session.hasLoadedContent
                )
                return
            }

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
        ScrollView {
            LHPageScaffold(horizontalPadding: 20, verticalPadding: 28, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LH2GPX")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("home.title")
                    Text(localize("Private location history → GPX, KML, CSV, KMZ"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HomeLocalPrivacyRow(localize: localize)

                if let message, message.kind == .error {
                    AppMessageCard(message: message)
                }

                Button(action: openAction) {
                    Text(localize("Import File"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(LH2GPXTheme.primaryBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("home.import.primary")

                GoogleMapsExportHelpInlineAction(
                    titleKey: "Google Maps Export Guide",
                    accessibilityIdentifier: "home.googleHelp"
                )

                HomeActionRow(
                    title: localize("Load Demo"),
                    systemImage: "testtube.2",
                    accessibilityIdentifier: "home.demo",
                    action: loadDemoAction
                )

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
            .background(LH2GPXTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
#endif
