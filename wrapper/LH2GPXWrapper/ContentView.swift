import SwiftUI
import LocationHistoryConsumerAppSupport
import LocationHistoryConsumerDemoSupport
import UniformTypeIdentifiers

struct ContentView: View {
    private enum LaunchArgument {
        static let uiTesting = "LH2GPX_UI_TESTING"
        static let resetPersistence = "LH2GPX_RESET_PERSISTENCE"
    }

    @State private var session = AppSessionState()
    @State private var isImportingFile = false
    @State private var isShowingOptions = false
    @State private var hasPreparedLaunchState = false
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
                            emptyStateView
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
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.json, .zip],
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

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(t("Import your location history"))
                    .font(.title2.weight(.semibold))
                Text(t("Open an app_export.json or .zip from the LocationHistory2GPX tool — or a Google Timeline location-history.json or .zip from Google Takeout."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let message = session.message, message.kind == .error {
                AppMessageCard(message: message)
            }

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

    private var launchArguments: Set<String> {
        Set(ProcessInfo.processInfo.arguments)
    }
}
