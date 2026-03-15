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
                AppContentSplitView(
                    session: $session,
                    sourceHint: "Open another file replaces the current content. Load Demo switches back to the bundled sample. Clear returns to the import-first start state."
                )
            } else if session.isLoading {
                ProgressView("Opening app export...")
            } else {
                AppShellEmptyStateView(
                    summary: session.sourceSummary,
                    message: session.message,
                    openAction: { isImportingFile = true },
                    loadDemoAction: loadBundledDemo,
                    clearAction: clearCurrentContent
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(openButtonTitle) {
                    isImportingFile = true
                }
                Button(demoButtonTitle) {
                    loadBundledDemo()
                }
                if session.hasLoadedContent || session.message != nil {
                    Button("Clear") {
                        clearCurrentContent()
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

    private var openButtonTitle: String {
        session.hasLoadedContent ? "Open Another File" : "Open app_export.json"
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName) ? "Reload Demo Data" : "Load Demo Data"
    }

    private func clearCurrentContent() {
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
            session.show(content: try AppContentLoader.loadImportedContent(from: url))
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
    let summary: AppSourceSummary
    let message: AppUserMessage?
    let openAction: () -> Void
    let loadDemoAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Open an app_export.json file")
                    .font(.title2.weight(.semibold))
                Text("This product-oriented shell reads local LocationHistory2GPX app_export contract files offline. Google raw exports, persistence and cloud features stay out of scope here.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            AppSourceSummaryCard(summary: summary)

            if let message, message.kind == .error {
                AppMessageCard(message: message)
            }

            VStack(alignment: .leading, spacing: 10) {
                Button("Open app_export.json", action: openAction)
                    .buttonStyle(.borderedProminent)
                Button("Load Demo Data", action: loadDemoAction)
                    .buttonStyle(.bordered)
                if message != nil {
                    Button("Clear", action: clearAction)
                        .buttonStyle(.bordered)
                }
                Text("Expected input is a local app_export.json file that matches the frozen consumer contract. Demo data remains optional and secondary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
#endif
