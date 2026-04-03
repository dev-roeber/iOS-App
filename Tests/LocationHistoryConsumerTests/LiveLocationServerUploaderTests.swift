import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import LocationHistoryConsumerAppSupport

// MARK: - URLProtocol mock (works on Linux + Apple via FoundationNetworking / Foundation)

/// Lock-protected registry so startLoading() (called on an arbitrary thread) can safely
/// read the handler that was installed by the test on the calling task.
private final class MockURLProtocolRegistry {
    private let lock = NSLock()
    private var _handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    static let shared = MockURLProtocolRegistry()

    func set(_ handler: @escaping (URLRequest) throws -> (Data, HTTPURLResponse)) {
        lock.lock(); defer { lock.unlock() }
        _handler = handler
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        _handler = nil
    }

    func handle(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        lock.lock(); defer { lock.unlock() }
        guard let h = _handler else {
            throw LiveLocationServerUploadError.invalidResponse
        }
        return try h(request)
    }
}

private final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (data, response) = try MockURLProtocolRegistry.shared.handle(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class LiveLocationServerUploaderTests: XCTestCase {

    private func makeUploader() -> HTTPSLiveLocationServerUploader {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return HTTPSLiveLocationServerUploader(session: session)
    }

    private func makeRequest(pointCount: Int = 1) -> LiveLocationUploadRequest {
        let base = Date(timeIntervalSince1970: 1_710_000_000)
        let points = (0..<pointCount).map { i in
            LiveLocationUploadPoint(
                latitude: 52.52 + Double(i) * 0.001,
                longitude: 13.40 + Double(i) * 0.001,
                timestamp: base.addingTimeInterval(Double(i) * 5),
                horizontalAccuracyM: 6.0
            )
        }
        return LiveLocationUploadRequest(
            source: "ios",
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            captureMode: "foreground",
            sentAt: base,
            points: points
        )
    }

    override func tearDown() {
        MockURLProtocolRegistry.shared.clear()
        super.tearDown()
    }

    // MARK: Success path

    func testUploadPostsToCorrectEndpoint() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!
        var captured: URLRequest?

        MockURLProtocolRegistry.shared.set { req in
            captured = req
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)

        XCTAssertEqual(captured?.url, endpoint)
        XCTAssertEqual(captured?.httpMethod, "POST")
    }

    func testUploadSetsContentTypeHeader() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!
        var captured: URLRequest?

        MockURLProtocolRegistry.shared.set { req in
            captured = req
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)

        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testUploadSetsBearerTokenHeader() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!
        var captured: URLRequest?

        MockURLProtocolRegistry.shared.set { req in
            captured = req
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: "supersecret")

        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer supersecret")
    }

    func testUploadOmitsAuthorizationHeaderWhenBearerTokenIsNil() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!
        var captured: URLRequest?

        MockURLProtocolRegistry.shared.set { req in
            captured = req
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)

        XCTAssertNil(captured?.value(forHTTPHeaderField: "Authorization"))
    }

    func testUploadEncodesBodyAsJSON() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!
        var capturedBody: Data?

        MockURLProtocolRegistry.shared.set { req in
            capturedBody = req.httpBody
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)

        XCTAssertNotNil(capturedBody)
        // Must be valid JSON
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: capturedBody!))
    }

    func testUploadSucceedsFor2xxStatus() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!

        for code in [200, 201, 204, 299] {
            MockURLProtocolRegistry.shared.set { req in
                return (Data(), HTTPURLResponse(url: req.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
            }
            // Must not throw
            try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)
        }
    }

    // MARK: Error paths

    func testUploadThrowsUnsuccessfulStatusCodeFor4xx() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!

        MockURLProtocolRegistry.shared.set { req in
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!)
        }

        do {
            try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)
            XCTFail("Expected unsuccessfulStatusCode error")
        } catch LiveLocationServerUploadError.unsuccessfulStatusCode(let code) {
            XCTAssertEqual(code, 422)
        }
    }

    func testUploadThrowsUnsuccessfulStatusCodeFor5xx() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!

        MockURLProtocolRegistry.shared.set { req in
            return (Data(), HTTPURLResponse(url: req.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
        }

        do {
            try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)
            XCTFail("Expected unsuccessfulStatusCode error")
        } catch LiveLocationServerUploadError.unsuccessfulStatusCode(let code) {
            XCTAssertEqual(code, 503)
        }
    }

    func testUploadPropagatesNetworkError() async throws {
        let uploader = makeUploader()
        let endpoint = URL(string: "https://example.invalid/live")!
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        MockURLProtocolRegistry.shared.set { _ in throw networkError }

        do {
            try await uploader.upload(request: makeRequest(), to: endpoint, bearerToken: nil)
            XCTFail("Expected network error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, NSURLErrorDomain)
            XCTAssertEqual(error.code, NSURLErrorNotConnectedToInternet)
        }
    }
}
