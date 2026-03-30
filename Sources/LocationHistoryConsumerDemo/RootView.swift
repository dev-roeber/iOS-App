#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumerAppSupport
import LocationHistoryConsumerDemoSupport
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct RootView: View {
    @State private var session = AppSessionState(isLoading: true)
    @State private var isImportingFile = false
    @StateObject private var liveLocation = LiveLocationFeatureModel()

    var body: some View {
        Group {
            if session.isLoading && !session.hasLoadedContent {
                ProgressView("Loading demo app export...")
            } else if session.content != nil {
                AppContentSplitView(session: $session, liveLocation: liveLocation)
            } else {
                DemoPlaceholderView(
                    title: session.message?.title ?? "No demo source loaded",
                    message: session.message?.message ?? "Load the bundled demo fixture or import a local app_export.json file."
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Load Demo") {
                    loadBundledDemo()
                }
                importButton
            }
        }
        .task {
            guard session.isLoading, !session.hasLoadedContent else { return }
            loadBundledDemo()
        }
        #if canImport(UniformTypeIdentifiers)
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        #endif
    }

    private var importButton: some View {
        Button("Import JSON") {
            isImportingFile = true
        }
    }

    private func loadBundledDemo() {
        session.beginLoading()
        do {
            session.show(content: try DemoDataLoader.loadDefaultContent())
        } catch {
            session.showFailure(
                title: "Unable to load demo fixture",
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
            Task { await loadImportedFile(at: url) }
        case let .failure(error):
            if isUserCancelled(error) {
                return
            }
            session.showFailure(
                title: "Import failed",
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
            session.show(content: try await DemoDataLoader.loadImportedContent(from: url))
        } catch {
            session.showFailure(
                title: "Import failed",
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

private struct DemoPlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
#endif
