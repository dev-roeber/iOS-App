#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
import LocationHistoryConsumerDemoSupport
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct RootView: View {
    @State private var session = DemoSessionState(isLoading: true)
    @State private var isImportingFile = false

    var body: some View {
        Group {
            if session.isLoading && !session.hasLoadedContent {
                ProgressView("Loading app export...")
            } else if session.content != nil {
                NavigationSplitView {
                    DayListView(
                        summaries: session.daySummaries,
                        selectedDate: Binding(
                            get: { session.selectedDate },
                            set: { session.selectDay($0) }
                        )
                    )
                    .safeAreaInset(edge: .bottom) {
                        sourceFooter
                    }
                    .navigationTitle("Days")
                } detail: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            SessionStatusView(
                                message: session.message,
                                sourceDescription: session.sourceDescription,
                                isLoading: session.isLoading,
                                hasDays: session.hasDays
                            )
                            if let overview = session.overview {
                                OverviewSection(overview: overview)
                            }
                            DayDetailView(
                                detail: session.selectedDetail,
                                hasDays: session.hasDays
                            )
                        }
                        .padding()
                    }
                    .navigationTitle(session.selectedDate ?? "Overview")
                }
            } else {
                PlaceholderStateView(
                    title: session.message?.title ?? "No app export loaded",
                    systemImage: "exclamationmark.triangle",
                    message: session.message?.message ?? "Load the demo fixture or import a local app_export.json file."
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
            let content = try DemoDataLoader.loadDefaultContent()
            session.show(content: content)
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
            loadImportedFile(at: url)
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

    private func loadImportedFile(at url: URL) {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let content = try DemoDataLoader.loadImportedContent(from: url)
            session.show(content: content)
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

    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Active Source")
                .font(.caption.weight(.semibold))
            Text(session.sourceDescription ?? "No source loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
            if session.hasLoadedContent {
                Text("Load Demo resets the harness back to the bundled sample.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.thinMaterial)
    }
}

private struct PlaceholderStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
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

private struct SessionStatusView: View {
    let message: DemoUserMessage?
    let sourceDescription: String?
    let isLoading: Bool
    let hasDays: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let sourceDescription {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Source")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(sourceDescription)
                        .font(.subheadline)
                }
            }

            if let message {
                MessageCard(message: message)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing app export...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !hasDays {
                Text("This app export currently has no day entries. Overview data is still shown above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MessageCard: View {
    let message: DemoUserMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.title)
                .font(.subheadline.weight(.semibold))
            Text(message.message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var backgroundColor: Color {
        switch message.kind {
        case .info:
            return Color.accentColor.opacity(0.12)
        case .error:
            return Color.red.opacity(0.12)
        }
    }
}
#endif
