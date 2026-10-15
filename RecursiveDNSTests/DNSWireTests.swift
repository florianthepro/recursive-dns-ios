import XCTest

final class DNSWireTests: XCTestCase {
    func testQueryRoundTrip() throws {
        let question = DNSQuestion(name: "example.com", type: 1, dnsClass: 1)
        let data = DNSPacket.query(id: 42, question: question)
        let packet = try DNSPacket(data: data)
        XCTAssertEqual(packet.id, 42)
        XCTAssertEqual(packet.questions, [question])
    }

    func testCompressedName() throws {
        var packet = DNSPacket.query(id: 1, question: DNSQuestion(name: "example.com", type: 1, dnsClass: 1))
        packet.append(contentsOf: [0xC0, 0x0C])
        var offset = packet.count - 2
        XCTAssertEqual(try packet.readName(&offset), "example.com")
    }
}
