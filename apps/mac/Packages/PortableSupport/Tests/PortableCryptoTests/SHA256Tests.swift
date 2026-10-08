import Foundation
import PortableCrypto
import Testing

@Suite struct SHA256Tests {
    private func hex(_ digest: SHA256Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    @Test func emptyMessage() {
        #expect(hex(SHA256.hash(data: Data())) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func abc() {
        #expect(hex(SHA256.hash(data: Data("abc".utf8))) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func twoBlockMessage() {
        let message = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(hex(SHA256.hash(data: Data(message.utf8))) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test func exactlyOneBlock() {
        let message = String(repeating: "a", count: 64)
        #expect(hex(SHA256.hash(data: Data(message.utf8))) == "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb")
    }

    @Test func fiftyFiveAndFiftySixBytes() {
        #expect(hex(SHA256.hash(data: Data(String(repeating: "a", count: 55).utf8))) == "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318")
        #expect(hex(SHA256.hash(data: Data(String(repeating: "a", count: 56).utf8))) == "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a")
    }

    @Test func millionAs() {
        let message = Data([UInt8](repeating: UInt8(ascii: "a"), count: 1_000_000))
        #expect(hex(SHA256.hash(data: message)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test func incrementalMatchesOneShot() {
        var bytes = [UInt8](repeating: 0, count: 10_000)
        for index in bytes.indices { bytes[index] = UInt8(truncatingIfNeeded: index &* 31 &+ 7) }
        let data = Data(bytes)
        let oneShot = SHA256.hash(data: data)
        for chunk in [1, 3, 63, 64, 65, 1000, 4096] {
            var hasher = SHA256()
            var offset = 0
            while offset < data.count {
                let end = min(offset + chunk, data.count)
                hasher.update(data: data[offset..<end])
                offset = end
            }
            #expect(hasher.finalize() == oneShot, "chunk size \(chunk)")
        }
    }

    @Test func digestIteratesThirtyTwoBytes() {
        let digest = SHA256.hash(data: Data("abc".utf8))
        #expect(Array(digest).count == 32)
        #expect(digest.prefix(4).map { String(format: "%02x", $0) }.joined() == "ba7816bf")
    }
}
