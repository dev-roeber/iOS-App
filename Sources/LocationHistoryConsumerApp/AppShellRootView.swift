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
                                openAction: { isImportingFile = true },
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
            allowedContentTypes: [.json, .zip],
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

    #if canImport(UniformTypeIdentifiers)
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                return
            }
            session.beginLoading()
            Task { await loadImportedFile(at: url) }
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
    private func loadImportedFile(at url: URL) async {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let content = try await AppContentLoader.loadImportedContent(from: url)
            ImportBookmarkStore.save(url: url)
            session.show(content: content)
        } catch {
            session.showFailure(
                title: (error as? AppContentLoaderError)?.userFacingTitle ?? "Unable to open file",
                message: error.localizedDescription,
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
    let openAction: () -> Void
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
}
#endif
