import Foundation
import LocationHistoryConsumer

public enum DemoMessageKind: Equatable {
    case info
    case error
}

public struct DemoUserMessage: Equatable {
    public let kind: DemoMessageKind
    public let title: String
    public let message: String

    public init(kind: DemoMessageKind, title: String, message: String) {
        self.kind = kind
        self.title = title
        self.message = message
    }
}

public struct DemoSessionState {
    public private(set) var isLoading: Bool
    public private(set) var content: DemoContent?
    public private(set) var selectedDate: String?
    public private(set) var message: DemoUserMessage?

    public init(
        isLoading: Bool = false,
        content: DemoContent? = nil,
        selectedDate: String? = nil,
        message: DemoUserMessage? = nil
    ) {
        self.isLoading = isLoading
        self.content = content
        self.selectedDate = selectedDate
        self.message = message
    }

    public var overview: ExportOverview? {
        content?.overview
    }

    public var daySummaries: [DaySummary] {
        content?.daySummaries ?? []
    }

    public var selectedDetail: DayDetailViewState? {
        content?.detail(for: selectedDate)
    }

    public var source: DemoContentSource? {
        content?.source
    }

    public var sourceDescription: String? {
        guard let source else {
            return nil
        }
        switch source {
        case let .bundledFixture(name):
            return "Demo fixture: \(name).json"
        case let .importedFile(filename):
            return "Imported file: \(filename)"
        }
    }

    public var hasLoadedContent: Bool {
        content != nil
    }

    public var hasDays: Bool {
        !daySummaries.isEmpty
    }

    public mutating func beginLoading() {
        isLoading = true
        message = nil
    }

    public mutating func show(content: DemoContent) {
        self.content = content
        selectedDate = content.selectedDate
        isLoading = false
        message = DemoUserMessage(
            kind: .info,
            title: content.source == .bundledFixture(name: DemoDataLoader.defaultFixtureName) ? "Demo ready" : "Imported app export ready",
            message: sourceDescription ?? content.source.displayName
        )
    }

    public mutating func selectDay(_ date: String?) {
        guard let date else {
            selectedDate = nil
            return
        }

        if daySummaries.contains(where: { $0.date == date }) {
            selectedDate = date
        } else {
            selectedDate = daySummaries.first?.date
        }
    }

    public mutating func showFailure(title: String, message: String, preserveCurrentContent: Bool) {
        isLoading = false
        self.message = DemoUserMessage(kind: .error, title: title, message: message)
        if !preserveCurrentContent {
            content = nil
            selectedDate = nil
        }
    }

    public mutating func clearMessage() {
        message = nil
    }
}
