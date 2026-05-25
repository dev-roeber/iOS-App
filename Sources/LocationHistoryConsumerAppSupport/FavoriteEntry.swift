import Foundation

/// Phase E (2026-05-25) — local-only favorite-metadata model.
///
/// Build-only foundation for a future iCloud-favorites-sync train.
/// In Phase E this struct is **never** written to or read from CloudKit;
/// `FavoriteEntryStore` persists it to a JSON file in
/// `Application Support/lh2gpx/favorites.json`.
///
/// **Privacy-safe by design** — the struct intentionally carries no
/// coordinates, polylines, altitudes, raw history payloads, file paths,
/// place IDs or auth tokens. The `legacyID` is the same ISO-8601 day
/// string the existing `DayFavoritesStore` already stores; it is the
/// stable join key between local UI and cloud, never a coordinate.
public struct FavoriteEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: UUID { favoriteID }

    /// Bumped when the on-disk shape needs a migration.
    public let schemaVersion: Int

    /// Stable cross-device identifier derived deterministically from
    /// `legacyID` + `itemKind` (see `FavoriteIDFactory`). Idempotent across
    /// app launches and devices that share the same legacy data.
    public let favoriteID: UUID

    /// Original identifier from the legacy `DayFavoritesStore` — an
    /// ISO-8601 day string ("YYYY-MM-DD") for `.day` favorites. Reserved
    /// for future item kinds (track, place) without breaking on-disk JSON.
    public let legacyID: String

    /// Kind of favorited item. Persisted as `rawValue` — do not rename.
    public let itemKind: FavoriteItemKind

    /// `true` while the favorite is active; flipped to `false` (tombstone)
    /// when the user un-stars the item locally. Lets a future sync engine
    /// propagate deletes without losing audit trail.
    public var isFavorite: Bool

    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        favoriteID: UUID,
        legacyID: String,
        itemKind: FavoriteItemKind,
        isFavorite: Bool,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        schemaVersion: Int = FavoriteEntry.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.favoriteID = favoriteID
        self.legacyID = legacyID
        self.itemKind = itemKind
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public static let currentSchemaVersion: Int = 1

    // MARK: - Codable (backward-compatible)

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, favoriteID, legacyID, itemKind, isFavorite
        case createdAt, updatedAt, deletedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try container.decodeIfPresent(Int.self, forKey: .schemaVersion))
            ?? FavoriteEntry.currentSchemaVersion
        favoriteID = try container.decode(UUID.self, forKey: .favoriteID)
        legacyID = try container.decode(String.self, forKey: .legacyID)
        itemKind = try container.decode(FavoriteItemKind.self, forKey: .itemKind)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(favoriteID, forKey: .favoriteID)
        try container.encode(legacyID, forKey: .legacyID)
        try container.encode(itemKind, forKey: .itemKind)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

/// Persisted enum — **never rename rawValues**. New cases append at the end.
public enum FavoriteItemKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// A favorited day from the imported history.
    case day
}

// MARK: - Deterministic favorite-ID factory

/// Maps `(legacyID, itemKind)` to a stable `UUID` so the same legacy
/// favorite produces the same `favoriteID` across app launches and
/// (eventually) across devices. UUIDv5-style — no random component.
///
/// Implementation uses SHA-256(`namespace + ":" + itemKind + ":" + legacyID`)
/// and reshapes the first 16 bytes into a valid UUID (RFC 4122 §4.4 layout
/// bits applied). The namespace is repo-internal and deliberately not a
/// real DNS domain — it just keeps the input deterministic and unique to
/// this app.
public enum FavoriteIDFactory {

    /// Repo-internal stable namespace string. **Do not change** — would
    /// break determinism for all existing favorites.
    public static let namespace = "de.roeber.LH2GPXWrapper.favorite"

    public static func deterministicID(
        legacyID: String,
        itemKind: FavoriteItemKind
    ) -> UUID {
        let input = "\(namespace):\(itemKind.rawValue):\(legacyID)"
        let bytes = sha256First16Bytes(of: input)
        return uuid(from: bytes)
    }

    // MARK: - Pure-Foundation SHA-256

    /// Foundation-only SHA-256, no `import CryptoKit` so the helper stays
    /// available on Linux test runs. Returns the first 16 raw bytes; the
    /// caller reshapes them into a UUID.
    private static func sha256First16Bytes(of input: String) -> [UInt8] {
        let message = Array(input.utf8)
        var hash: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ]
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        ]

        var padded = message
        let bitLength = UInt64(message.count) * 8
        padded.append(0x80)
        while padded.count % 64 != 56 { padded.append(0x00) }
        for i in (0..<8).reversed() {
            padded.append(UInt8((bitLength >> (UInt64(i) * 8)) & 0xff))
        }

        for chunkStart in stride(from: 0, to: padded.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let base = chunkStart + i * 4
                w[i] = (UInt32(padded[base]) << 24) | (UInt32(padded[base + 1]) << 16) |
                       (UInt32(padded[base + 2]) << 8) | UInt32(padded[base + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var (a, b, c, d, e, f, g, h) = (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7])
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let mj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ mj
                h = g; g = f; f = e
                e = d &+ t1
                d = c; c = b; b = a
                a = t1 &+ t2
            }
            hash[0] = hash[0] &+ a
            hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c
            hash[3] = hash[3] &+ d
            hash[4] = hash[4] &+ e
            hash[5] = hash[5] &+ f
            hash[6] = hash[6] &+ g
            hash[7] = hash[7] &+ h
        }

        var out: [UInt8] = []
        for word in hash[0..<4] {
            out.append(UInt8((word >> 24) & 0xff))
            out.append(UInt8((word >> 16) & 0xff))
            out.append(UInt8((word >> 8) & 0xff))
            out.append(UInt8(word & 0xff))
        }
        return out
    }

    @inline(__always)
    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }

    private static func uuid(from bytes: [UInt8]) -> UUID {
        precondition(bytes.count >= 16)
        var b = bytes
        // RFC 4122 §4.4 — bake version 5 + variant bits.
        b[6] = (b[6] & 0x0f) | 0x50
        b[8] = (b[8] & 0x3f) | 0x80
        let raw = uuid_t(
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
        )
        return UUID(uuid: raw)
    }
}
