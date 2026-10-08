import Foundation

// A source-compatible subset of CryptoKit's SHA256 for platforms without
// CryptoKit: one-shot `SHA256.hash(data:)`, incremental `update`/`finalize`,
// and a digest that iterates its bytes. FIPS 180-4, pure Swift.

public struct SHA256Digest: Sequence, Hashable, Sendable, CustomStringConvertible {
    public typealias Element = UInt8

    public static let byteCount = 32

    private let bytes: [UInt8]

    init(bytes: [UInt8]) {
        precondition(bytes.count == Self.byteCount)
        self.bytes = bytes
    }

    public func makeIterator() -> IndexingIterator<[UInt8]> {
        bytes.makeIterator()
    }

    public var underestimatedCount: Int { bytes.count }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }

    public var description: String {
        "SHA256 digest: " + bytes.map { String(format: "%02x", $0) }.joined()
    }
}

public struct SHA256: Sendable {
    public static let blockByteCount = 64
    public static let byteCount = 32

    private var state: [UInt32] = [
        0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a,
        0x510e_527f, 0x9b05_688c, 0x1f83_d9ab, 0x5be0_cd19,
    ]
    private var buffer: [UInt8] = []
    private var messageLength: UInt64 = 0

    public init() {
        buffer.reserveCapacity(Self.blockByteCount)
    }

    public static func hash<D: DataProtocol>(data: D) -> SHA256Digest {
        var hasher = SHA256()
        hasher.update(data: data)
        return hasher.finalize()
    }

    public mutating func update<D: DataProtocol>(data: D) {
        for region in data.regions {
            region.withUnsafeBytes { update(bufferPointer: $0) }
        }
    }

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        guard !bufferPointer.isEmpty else { return }
        messageLength &+= UInt64(bufferPointer.count)
        var offset = 0
        if !buffer.isEmpty {
            let needed = Self.blockByteCount - buffer.count
            let take = min(needed, bufferPointer.count)
            buffer.append(contentsOf: UnsafeRawBufferPointer(rebasing: bufferPointer[0..<take]))
            offset = take
            if buffer.count == Self.blockByteCount {
                buffer.withUnsafeBytes { Self.compress(&state, block: $0) }
                buffer.removeAll(keepingCapacity: true)
            }
        }
        while bufferPointer.count - offset >= Self.blockByteCount {
            Self.compress(&state, block: UnsafeRawBufferPointer(rebasing: bufferPointer[offset..<offset + Self.blockByteCount]))
            offset += Self.blockByteCount
        }
        if offset < bufferPointer.count {
            buffer.append(contentsOf: UnsafeRawBufferPointer(rebasing: bufferPointer[offset...]))
        }
    }

    public func finalize() -> SHA256Digest {
        var copy = self
        var padding: [UInt8] = [0x80]
        let remainder = (copy.buffer.count + 1) % Self.blockByteCount
        let zeros = remainder <= 56 ? 56 - remainder : Self.blockByteCount + 56 - remainder
        padding.append(contentsOf: [UInt8](repeating: 0, count: zeros))
        let bitLength = copy.messageLength &* 8
        for shift in stride(from: 56, through: 0, by: -8) {
            padding.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }
        let savedLength = copy.messageLength
        copy.update(bufferPointer: padding.withUnsafeBytes { UnsafeRawBufferPointer($0) })
        copy.messageLength = savedLength
        precondition(copy.buffer.isEmpty)
        var out = [UInt8](repeating: 0, count: Self.byteCount)
        for (index, word) in copy.state.enumerated() {
            out[index * 4] = UInt8(truncatingIfNeeded: word >> 24)
            out[index * 4 + 1] = UInt8(truncatingIfNeeded: word >> 16)
            out[index * 4 + 2] = UInt8(truncatingIfNeeded: word >> 8)
            out[index * 4 + 3] = UInt8(truncatingIfNeeded: word)
        }
        return SHA256Digest(bytes: out)
    }

    private static let k: [UInt32] = [
        0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1, 0x923f_82a4, 0xab1c_5ed5,
        0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3, 0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7, 0xc19b_f174,
        0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc, 0x76f9_88da,
        0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7, 0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351, 0x1429_2967,
        0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13, 0x650a_7354, 0x766a_0abb, 0x81c2_c92e, 0x9272_2c85,
        0xa2bf_e8a1, 0xa81a_664b, 0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585, 0x106a_a070,
        0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f, 0x682e_6ff3,
        0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208, 0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7, 0xc671_78f2,
    ]

    private static func compress(_ state: inout [UInt32], block: UnsafeRawBufferPointer) {
        var w = [UInt32](repeating: 0, count: 64)
        for t in 0..<16 {
            let i = t * 4
            w[t] = UInt32(block[i]) << 24 | UInt32(block[i + 1]) << 16 | UInt32(block[i + 2]) << 8 | UInt32(block[i + 3])
        }
        for t in 16..<64 {
            let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
            let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
            w[t] = w[t - 16] &+ s0 &+ w[t - 7] &+ s1
        }

        var a = state[0], b = state[1], c = state[2], d = state[3]
        var e = state[4], f = state[5], g = state[6], h = state[7]

        for t in 0..<64 {
            let bigS1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let ch = (e & f) ^ (~e & g)
            let t1 = h &+ bigS1 &+ ch &+ k[t] &+ w[t]
            let bigS0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let t2 = bigS0 &+ maj
            h = g
            g = f
            f = e
            e = d &+ t1
            d = c
            c = b
            b = a
            a = t1 &+ t2
        }

        state[0] &+= a
        state[1] &+= b
        state[2] &+= c
        state[3] &+= d
        state[4] &+= e
        state[5] &+= f
        state[6] &+= g
        state[7] &+= h
    }

    @inline(__always)
    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }
}
