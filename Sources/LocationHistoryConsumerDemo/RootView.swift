#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
import LocationHistoryConsumerDemoSupport
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct RootView: View {
    @State private var state: LoadState = .loading
    @State private var selectedDate: String?
    @State private var isImportingFile = false

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading app export...")
            case let .failed(message):
                PlaceholderStateView(
                    title: "Unable to load app export",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
            case let .loaded(content):
                NavigationSplitView {
                    DayListView(
                        summaries: content.daySummaries,
                        selectedDate: $selectedDate
                    )
                    .safeAreaInset(edge: .bottom) {
                        sourceFooter(content.source)
                    }
                    .navigationTitle("Days")
                } detail: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            OverviewSection(overview: content.overview)
                            DayDetailView(detail: content.detail(for: selectedDate))
                        }
                        .padding()
                    }
                    .navigationTitle(selectedDate ?? "Overview")
                }
                .task {
                    if selectedDate == nil {
                        selectedDate = content.selectedDate
                    }
                }
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
            guard case .loading = state else { return }
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
        do {
            let content = try DemoDataLoader.loadDefaultContent()
            state = .loaded(content)
            selectedDate = content.selectedDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    #if canImport(UniformTypeIdentifiers)
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                state = .failed("No file was selected.")
                return
            }
            loadImportedFile(at: url)
        case let .failure(error):
            state = .failed(error.localizedDescription)
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
            state = .loaded(content)
            selectedDate = content.selectedDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
    #endif

    @ViewBuilder
    private func sourceFooter(_ source: DemoContentSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Source")
                .font(.caption.weight(.semibold))
            Text(sourceLabel(for: source))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.thinMaterial)
    }

    private func sourceLabel(for source: DemoContentSource) -> String {
        switch source {
        case let .bundledFixture(name):
            return "Demo fixture: \(name).json"
        case let .importedFile(filename):
            return "Imported file: \(filename)"
        }
    }
}

private enum LoadState {
    case loading
    case loaded(DemoContent)
    case failed(String)
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
#endif
