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

    var body: some View {
        Group {
            if session.content != nil {
                AppContentSplitView(session: $session)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
            } else {
                NavigationStack {
                    Group {
                        if session.isLoading {
                            ProgressView("Opening app export...")
                        } else {
                            AppShellEmptyStateView(
                                message: session.message,
                                openAction: { isImportingFile = true },
                                loadDemoAction: loadBundledDemo,
                                clearAction: clearCurrentContent
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
        #if canImport(UniformTypeIdentifiers)
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        #endif
        .task {
            // PARKED: Auto-restore temporarily disabled (Phase 19.5).
            // restoreBookmarkedFile()
            // App always starts at the manual import/demo entry point.
        }
    }

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            Button {
                isImportingFile = true
            } label: {
                Label(openButtonTitle, systemImage: "doc.badge.plus")
            }
            Button(action: loadBundledDemo) {
                Label(demoButtonTitle, systemImage: "testtube.2")
            }
            if session.hasLoadedContent || session.message?.kind == .error {
                Divider()
                Button(role: .destructive, action: clearCurrentContent) {
                    Label("Clear", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
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
        session.hasLoadedContent ? "Open Another File" : "Open app_export.json"
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName) ? "Reload Demo" : "Demo Data"
    }

    private func clearCurrentContent() {
        ImportBookmarkStore.clear()
        session.clearContent()
    }

    private func restoreBookmarkedFile() {
        guard !session.hasLoadedContent, !session.isLoading else {
            return
        }
        guard let url = ImportBookmarkStore.restore() else {
            return
        }
        session.beginLoading()
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            session.show(content: try AppContentLoader.loadImportedContent(from: url))
        } catch {
            ImportBookmarkStore.clear()
            session.showFailure(
                title: "Unable to restore previous import",
                message: error.localizedDescription,
                preserveCurrentContent: false
            )
        }
    }

    #if canImport(UniformTypeIdentifiers)
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                return
            }
            session.beginLoading()
            loadImportedFile(at: url)
        case let .failure(error):
            if isUserCancelled(error) {
                return
            }
            session.showFailure(
                title: "Unable to open app export",
                message: error.localizedDescription,
                preserveCurrentContent: session.hasLoadedContent
            )
        }
    }

    private func loadImportedFile(at url: URL) {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let content = try AppContentLoader.loadImportedContent(from: url)
            ImportBookmarkStore.save(url: url)
            session.show(content: content)
        } catch {
            session.showFailure(
                title: "Unable to open app export",
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

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Import your location history")
                    .font(.title2.weight(.semibold))
                Text("Open a local app_export.json file created with the LocationHistory2GPX tool to explore your location history offline.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let message, message.kind == .error {
                AppMessageCard(message: message)
            }

            VStack(spacing: 10) {
                Button(action: openAction) {
                    Label("Open app_export.json", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Button(action: loadDemoAction) {
                    Label("Load Demo Data", systemImage: "testtube.2")
                }
                .buttonStyle(.bordered)
                if message?.kind == .error {
                    Button(action: clearAction) {
                        Label("Clear", systemImage: "xmark.circle")
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
