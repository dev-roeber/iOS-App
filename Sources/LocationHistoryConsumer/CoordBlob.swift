import Foundation

/// Phase-1 spike of the LocalTimelineStore coordinate-blob format.
///
/// Encodes a sequence of WGS84 lat/lon pairs as packed little-endian
/// `Int32` microdegrees: 4 bytes lat + 4 bytes lon = **8 bytes per point**.
/// At 1e-6 degree resolution this is ~11 cm at the equator, well below GPS
/// noise. Halves on-disk size vs. a `[Double]` of pairs (16 bytes/point)
/// and removes IEEE-754 normalisation cost on read.
///
/// Decoding is via a lazy `CoordBlobIterator` (`Sequence`/`IteratorProtocol`):
/// the standard path never materialises a `[Double]`. A `decodeAll` helper
/// is provided for tests only.
///
/// This file is plattformneutral (Foundation only) and therefore Linux-testbar.
public enum CoordBlobError: Error, Equatable {
    case invalidCoordinate(latitude: Double, longitude: Double)
    case unevenFlatCoordinateCount(Int)
    case malformedBlobLength(Int)
    case outOfRange(latitude: Double, longitude: Double)
}

/// Single decoded coordinate. Public so distance helpers can iterate without
/// pulling in Apple-specific types.
public struct EncodedCoordinate: Equatable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum CoordBlobEncoding {
    /// Identifier persisted in `paths.coord_encoding`.
    public static let int32MicrodegreesV1 = "int32-microdeg-v1"

    /// Bytes per encoded point. Exposed for storage planning + tests.
    public static let bytesPerPoint = 8

    private static let scale: Double = 1_000_000.0
}

public enum CoordBlobEncoder {
    /// Encode a flat `[lat, lon, lat, lon, …]` array into a packed blob.
    /// Throws on uneven length or non-finite / out-of-range coordinates.
    public static func encode(flatCoordinates flat: [Double]) throws -> Data {
        guard flat.count.isMultiple(of: 2) else {
            throw CoordBlobError.unevenFlatCoordinateCount(flat.count)
        }
        let pointCount = flat.count / 2
        var data = Data()
        data.reserveCapacity(pointCount * CoordBlobEncoding.bytesPerPoint)
        var index = 0
        while index < flat.count {
            let lat = flat[index]
            let lon = flat[index + 1]
            try appendPoint(latitude: lat, longitude: lon, into: &data)
            index += 2
        }
        return data
    }

    /// Encode a generic sequence of `(lat, lon)` pairs.
    public static func encode<S: Sequence>(_ pairs: S) throws -> Data
    where S.Element == (Double, Double) {
        var data = Data()
        for (lat, lon) in pairs {
            try appendPoint(latitude: lat, longitude: lon, into: &data)
        }
        return data
    }

    private static func appendPoint(latitude lat: Double,
                                    longitude lon: Double,
                                    into data: inout Data) throws {
        guard lat.isFinite, lon.isFinite else {
            throw CoordBlobError.invalidCoordinate(latitude: lat, longitude: lon)
        }
        guard (-90.0...90.0).contains(lat),
              (-180.0...180.0).contains(lon) else {
            throw CoordBlobError.outOfRange(latitude: lat, longitude: lon)
        }
        let latE6 = Int32((lat * 1_000_000.0).rounded())
        let lonE6 = Int32((lon * 1_000_000.0).rounded())
        appendInt32LE(latE6, into: &data)
        appendInt32LE(lonE6, into: &data)
    }

    private static func appendInt32LE(_ value: Int32, into data: inout Data) {
        let bits = UInt32(bitPattern: value)
        data.append(UInt8(truncatingIfNeeded: bits))
        data.append(UInt8(truncatingIfNeeded: bits >> 8))
        data.append(UInt8(truncatingIfNeeded: bits >> 16))
        data.append(UInt8(truncatingIfNeeded: bits >> 24))
    }
}

/// Streaming decoder. Walks the blob 8 bytes at a time and yields
/// `EncodedCoordinate` without ever building a `[Double]`. Conforms to
/// `Sequence` so callers can `for c in iterator { … }` or `reduce` over it.
public struct CoordBlobIterator: Sequence, IteratorProtocol {
    public let blob: Data
    private var offset: Int

    public init(blob: Data) throws {
        guard blob.count.isMultiple(of: CoordBlobEncoding.bytesPerPoint) else {
            throw CoordBlobError.malformedBlobLength(blob.count)
        }
        self.blob = blob
        self.offset = 0
    }

    public var pointCount: Int {
        blob.count / CoordBlobEncoding.bytesPerPoint
    }

    public mutating func next() -> EncodedCoordinate? {
        guard offset + CoordBlobEncoding.bytesPerPoint <= blob.count else {
            return nil
        }
        let latE6 = readInt32LE(at: offset)
        let lonE6 = readInt32LE(at: offset + 4)
        offset += CoordBlobEncoding.bytesPerPoint
        return EncodedCoordinate(
            latitude: Double(latE6) / 1_000_000.0,
            longitude: Double(lonE6) / 1_000_000.0
        )
    }

    private func readInt32LE(at byteOffset: Int) -> Int32 {
        let base = blob.startIndex + byteOffset
        let b0 = UInt32(blob[base])
        let b1 = UInt32(blob[base + 1]) << 8
        let b2 = UInt32(blob[base + 2]) << 16
        let b3 = UInt32(blob[base + 3]) << 24
        return Int32(bitPattern: b0 | b1 | b2 | b3)
    }

    /// Test-only convenience. Production code paths must iterate lazily.
    public static func decodeAll(_ blob: Data) throws -> [EncodedCoordinate] {
        var iterator = try CoordBlobIterator(blob: blob)
        var out: [EncodedCoordinate] = []
        out.reserveCapacity(iterator.pointCount)
        while let p = iterator.next() { out.append(p) }
        return out
    }
}
