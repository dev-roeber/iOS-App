import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct LiveLocationServerUploadConfiguration: Equatable {
    public static let defaultTestEndpointURLString = "https://178-104-51-78.sslip.io/live-location"

    public var isEnabled: Bool
    public var endpointURLString: String
    public var bearerToken: String
    public var minimumBatchSize: Int

    public init(
        isEnabled: Bool = false,
        endpointURLString: String = LiveLocationServerUploadConfiguration.defaultTestEndpointURLString,
        bearerToken: String = "",
        minimumBatchSize: Int = 5
    ) {
        self.isEnabled = isEnabled
        self.endpointURLString = endpointURLString
        self.bearerToken = bearerToken
        self.minimumBatchSize = minimumBatchSize
    }

    public var endpointURL: URL? {
        let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }
        // Enforce https unless it's a localhost endpoint (e.g. for development)
        if let host = url.host?.lowercased(), host == "localhost" || host == "127.0.0.1" {
            return (scheme == "https" || scheme == "http") ? url : nil
        }
        return scheme == "https" ? url : nil
    }

    public var trimmedBearerToken: String? {
        let trimmed = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var endpointDisplayName: String {
        endpointURL?.host ?? endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct LiveLocationUploadPoint: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date
    public let horizontalAccuracyM: Double
}

public struct LiveLocationUploadRequest: Codable, Equatable {
    public let source: String
    public let sessionID: UUID
    public let captureMode: String
    public let sentAt: Date
    public let points: [LiveLocationUploadPoint]
}

public protocol LiveLocationServerUploading {
    func upload(
        request: LiveLocationUploadRequest,
        to endpoint: URL,
        bearerToken: String?
    ) async throws
}

public enum LiveLocationServerUploadError: LocalizedError {
    case invalidResponse
    case unsuccessfulStatusCode(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case let .unsuccessfulStatusCode(code):
            return "The server returned HTTP \(code)."
        }
    }
}

public final class HTTPSLiveLocationServerUploader: LiveLocationServerUploading {
    private let session: URLSession
    private let encoder: JSONEncoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys]
    }

    public func upload(
        request: LiveLocationUploadRequest,
        to endpoint: URL,
        bearerToken: String?
    ) async throws {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(request)

        let (_, response) = try await data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LiveLocationServerUploadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LiveLocationServerUploadError.unsuccessfulStatusCode(httpResponse.statusCode)
        }
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: LiveLocationServerUploadError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
