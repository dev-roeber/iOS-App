import Foundation

/// Element-based streaming reader for Google Timeline JSON exports.
///
/// Google Timeline is a top-level JSON array of objects (visits, activities,
/// path segments). A naive `JSONSerialization.jsonObject(with:)` over a
/// 46–100 MB export allocates a full Foundation tree (~150–200 MB transient)
/// on top of the source `Data`, which on iOS reliably trips Jetsam on devices
/// with 4 GB RAM.
///
/// This reader walks the array byte-by-byte via a tiny state machine,
/// isolates each top-level object, and parses only that single object via
/// `JSONSerialization`. Per-element peak memory is the size of the element
/// (~few KB), independent of total file size.
///
/// We deliberately accept only **object** elements at the top level — the
/// only shape Google emits. Numbers, strings, booleans, nulls, or nested
/// arrays as elements throw `.malformedJSON`. RFC-8259 whitespace and a
/// leading UTF-8 BOM are skipped; trailing whitespace after `]` is tolerated.
public enum GoogleTimelineStreamReader {

    public enum StreamError: Error {
        /// Top-level value was not a JSON array.
        case notArray
        /// Encountered a structurally invalid byte (e.g. a non-object element,
        /// truncated input, garbage after the closing bracket).
        case malformedJSON
        /// `FileHandle` could not be opened or read failed mid-file.
        case ioFailure
        /// A single element exceeded `maxElementBytes`. Defensive guard so a
        /// pathological file cannot allocate unbounded memory per element.
        case elementTooLarge
    }

    public struct Limits {
        /// Bytes pulled per `FileHandle.read` call. 64 KB is a sweet spot for
        /// APFS on iOS — large enough to amortise syscall overhead, small
        /// enough that the inner per-byte loop stays cache-friendly.
        public let chunkSize: Int
        /// Hard ceiling per top-level element. Real Google Timeline elements
        /// are a few KB; 8 MB leaves headroom for outliers without giving a
        /// crafted file room to OOM the device.
        public let maxElementBytes: Int

        public init(chunkSize: Int = 64 * 1024, maxElementBytes: Int = 8 * 1024 * 1024) {
            self.chunkSize = chunkSize
            self.maxElementBytes = maxElementBytes
        }
    }

    /// Streams elements from a file on disk. Closure is invoked once per
    /// top-level object; rethrows escape unchanged. Per-element memory peaks
    /// at the element's serialised size; the source file is read in chunks.
    public static func forEachObjectElement(
        contentsOf url: URL,
        limits: Limits = Limits(),
        onElement: (Any) throws -> Void
    ) throws {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw StreamError.ioFailure
        }
        defer { try? handle.close() }

        var parser = TopLevelArrayParser(maxElementBytes: limits.maxElementBytes)
        while true {
            let chunk: Data?
            do {
                chunk = try handle.read(upToCount: limits.chunkSize)
            } catch {
                throw StreamError.ioFailure
            }
            guard let bytes = chunk, !bytes.isEmpty else { break }
            try parser.feed(bytes, onElement: onElement)
        }
        try parser.finish()
    }

    /// Streams elements from an in-memory `Data` (used when the source is a
    /// ZIP entry that has already been extracted). Avoids a second full-tree
    /// JSON parse on top of the already-allocated `Data`.
    public static func forEachObjectElement(
        in data: Data,
        limits: Limits = Limits(),
        onElement: (Any) throws -> Void
    ) throws {
        var parser = TopLevelArrayParser(maxElementBytes: limits.maxElementBytes)
        try parser.feed(data, onElement: onElement)
        try parser.finish()
    }
}

// MARK: - State machine

private struct TopLevelArrayParser {
    enum State {
        case preArray       // skipping whitespace + BOM, expecting `[`
        case inArray        // between elements: skip whitespace/commas, expect `{` or `]`
        case inElement      // inside an object: depth-track until depth returns to 0
        case finished       // saw the closing `]`; only trailing whitespace allowed
    }

    var state: State = .preArray
    var bomChecked = false
    var element = Data()
    var depth = 0
    var inString = false
    var escape = false
    let maxElementBytes: Int

    init(maxElementBytes: Int) {
        self.maxElementBytes = maxElementBytes
        element.reserveCapacity(8 * 1024)
    }

    mutating func feed(_ data: Data, onElement: (Any) throws -> Void) throws {
        var cursor = data.startIndex
        if !bomChecked {
            bomChecked = true
            // UTF-8 BOM (EF BB BF). Drop only if present at the very start.
            if data.count >= 3,
               data[cursor] == 0xEF,
               data[data.index(cursor, offsetBy: 1)] == 0xBB,
               data[data.index(cursor, offsetBy: 2)] == 0xBF {
                cursor = data.index(cursor, offsetBy: 3)
            }
        }
        while cursor < data.endIndex {
            let byte = data[cursor]
            try processByte(byte, onElement: onElement)
            cursor = data.index(after: cursor)
        }
    }

    mutating func finish() throws {
        switch state {
        case .preArray, .inElement:
            throw GoogleTimelineStreamReader.StreamError.malformedJSON
        case .inArray:
            // Reached EOF without a closing `]`. Strict: malformed.
            throw GoogleTimelineStreamReader.StreamError.malformedJSON
        case .finished:
            return
        }
    }

    private mutating func processByte(_ byte: UInt8, onElement: (Any) throws -> Void) throws {
        switch state {
        case .preArray:
            if isJSONWhitespace(byte) { return }
            guard byte == UInt8(ascii: "[") else {
                throw GoogleTimelineStreamReader.StreamError.notArray
            }
            state = .inArray

        case .inArray:
            if isJSONWhitespace(byte) || byte == UInt8(ascii: ",") { return }
            if byte == UInt8(ascii: "]") {
                state = .finished
                return
            }
            // Only objects are accepted as top-level elements.
            guard byte == UInt8(ascii: "{") else {
                throw GoogleTimelineStreamReader.StreamError.malformedJSON
            }
            element.removeAll(keepingCapacity: true)
            element.append(byte)
            depth = 1
            inString = false
            escape = false
            state = .inElement

        case .inElement:
            element.append(byte)
            if element.count > maxElementBytes {
                throw GoogleTimelineStreamReader.StreamError.elementTooLarge
            }
            if escape {
                escape = false
                return
            }
            if inString {
                if byte == UInt8(ascii: "\\") {
                    escape = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
                return
            }
            // Outside string: structure-tracking only. We deliberately do not
            // validate JSON-grammar correctness inside the element — the
            // per-element JSONSerialization call does that.
            if byte == UInt8(ascii: "\"") {
                inString = true
                return
            }
            if byte == UInt8(ascii: "{") || byte == UInt8(ascii: "[") {
                depth += 1
                return
            }
            if byte == UInt8(ascii: "}") || byte == UInt8(ascii: "]") {
                depth -= 1
                if depth == 0 {
                    let parsed: Any
                    do {
                        parsed = try JSONSerialization.jsonObject(with: element)
                    } catch {
                        throw GoogleTimelineStreamReader.StreamError.malformedJSON
                    }
                    try onElement(parsed)
                    state = .inArray
                }
            }

        case .finished:
            if isJSONWhitespace(byte) { return }
            throw GoogleTimelineStreamReader.StreamError.malformedJSON
        }
    }

    private func isJSONWhitespace(_ b: UInt8) -> Bool {
        b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D
    }
}
