import Foundation

/// Element-based streaming reader for Google Timeline JSON exports.
///
/// Google Timeline is a top-level JSON array of objects (visits, activities,
/// path segments). A naive `JSONSerialization.jsonObject(with:)` over a
/// 46–100 MB export allocates a full Foundation tree (~150–200 MB transient)
/// on top of the source `Data`, which on iOS reliably trips Jetsam on
/// devices with 4 GB RAM.
///
/// This reader walks the array via a tiny state machine over an
/// `UnsafeBufferPointer<UInt8>` (raw byte access — Swift's `Data.Index`
/// iteration is ~5–10× slower for tight per-byte loops), isolates each
/// top-level object, and parses only that single object via
/// `JSONSerialization`. Per-element peak memory is the size of the
/// element (~few KB), independent of total file size.
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
        /// Bytes pulled per `FileHandle.read` call. 256 KB amortises syscall
        /// overhead well on APFS and keeps the inner loop's working set inside
        /// L2 cache on Apple Silicon.
        public let chunkSize: Int
        /// Hard ceiling per top-level element. Real Google Timeline elements
        /// are a few KB; 8 MB leaves headroom for outliers without giving a
        /// crafted file room to OOM the device.
        public let maxElementBytes: Int

        public init(chunkSize: Int = 256 * 1024, maxElementBytes: Int = 8 * 1024 * 1024) {
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

    /// Stateful incremental parser for callers that produce data in arbitrary
    /// chunks — for example, ZIPFoundation's `Archive.extract(_:bufferSize:)`
    /// callback delivering decompressed bytes one buffer at a time.
    /// Audit P1-5 / Block 2: previously the only way to consume a Google
    /// Timeline JSON inside a ZIP was to extract the entry to a full `Data`
    /// first, doubling peak RAM. With this incremental parser, callers can
    /// pump chunks straight from the ZIP into the per-element pipeline so
    /// peak memory matches the file-on-disk path.
    public final class IncrementalParser {
        private var parser: TopLevelArrayParser
        private var finished = false

        public init(limits: Limits = Limits()) {
            self.parser = TopLevelArrayParser(maxElementBytes: limits.maxElementBytes)
        }

        /// Feeds the next chunk of input. Throws on the first malformed byte
        /// or when an element exceeds `Limits.maxElementBytes`. `onElement`
        /// is invoked once per top-level object as it is closed.
        public func feed(_ chunk: Data, onElement: (Any) throws -> Void) throws {
            try parser.feed(chunk, onElement: onElement)
        }

        /// Asserts that the closing `]` has been seen. Call exactly once
        /// after the last `feed`. Throws if input was truncated mid-element.
        public func finish() throws {
            guard !finished else { return }
            try parser.finish()
            finished = true
        }
    }
}

// MARK: - State machine

private struct TopLevelArrayParser {
    enum State: UInt8 {
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
        // Pull a contiguous byte buffer. `Data.withUnsafeBytes` is the
        // cheapest path for tight inner loops; subscript-by-Index iteration
        // measurably regresses on 50k-element inputs.
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            var i = 0
            let count = raw.count

            // Drop UTF-8 BOM (EF BB BF) only at the very start of the stream.
            if !bomChecked {
                bomChecked = true
                if count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
                    i = 3
                }
            }

            while i < count {
                let byte = bytes[i]
                try processByte(byte, onElement: onElement)
                i += 1
            }
        }
    }

    mutating func finish() throws {
        switch state {
        case .preArray, .inElement, .inArray:
            // Reached EOF without a closing `]`. Strict: malformed.
            throw GoogleTimelineStreamReader.StreamError.malformedJSON
        case .finished:
            return
        }
    }

    @inline(__always)
    private mutating func processByte(_ byte: UInt8, onElement: (Any) throws -> Void) throws {
        switch state {
        case .preArray:
            if isJSONWhitespace(byte) { return }
            guard byte == 0x5B else { // '['
                throw GoogleTimelineStreamReader.StreamError.notArray
            }
            state = .inArray

        case .inArray:
            if isJSONWhitespace(byte) || byte == 0x2C { return } // ','
            if byte == 0x5D { // ']'
                state = .finished
                return
            }
            // Only objects are accepted as top-level elements.
            guard byte == 0x7B else { // '{'
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
                if byte == 0x5C {        // '\\'
                    escape = true
                } else if byte == 0x22 { // '"'
                    inString = false
                }
                return
            }
            // Outside string: structure-tracking only. We deliberately do not
            // validate JSON-grammar correctness inside the element — the
            // per-element JSONSerialization call does that.
            if byte == 0x22 {            // '"'
                inString = true
                return
            }
            if byte == 0x7B || byte == 0x5B { // '{' '['
                depth += 1
                return
            }
            if byte == 0x7D || byte == 0x5D { // '}' ']'
                depth -= 1
                if depth == 0 {
                    let parsed: Any
                    do {
                        parsed = try JSONSerialization.jsonObject(with: element)
                    } catch {
                        throw GoogleTimelineStreamReader.StreamError.malformedJSON
                    }
                    // Wrap per-element work in an autoreleasepool so the
                    // intermediate Foundation objects (NSString, NSNumber,
                    // NSDictionary, NSArray) don't accumulate across the
                    // whole import — on a 50k-element file that adds up to
                    // hundreds of MB of autorelease pressure otherwise.
                    try autoreleasepool {
                        try onElement(parsed)
                    }
                    state = .inArray
                }
            }
        case .finished:
            if isJSONWhitespace(byte) { return }
            throw GoogleTimelineStreamReader.StreamError.malformedJSON
        }
    }

    @inline(__always)
    private func isJSONWhitespace(_ b: UInt8) -> Bool {
        b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D
    }
}
