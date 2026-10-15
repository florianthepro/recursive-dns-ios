import XCTest

final class DNSWireTests:XCTestCase{
    func testQueryRoundTrip()throws{let q=DNSQuestion(name:"example.com",type:1,dnsClass:1),d=DNSPacket.query(id:42,question:q),p=try DNSPacket(data:d);XCTAssertEqual(p.id,42);XCTAssertEqual(p.questions,[q])}
    func testCompressedName()throws{var d=DNSPacket.query(id:1,question:.init(name:"example.com",type:1,dnsClass:1));d.append(contentsOf:[0xc0,0x0c]);var offset=d.count-2;XCTAssertEqual(try d.readName(&offset),"example.com")}
    func testServFailKeepsIdentifier(){let q=DNSPacket.query(id:0xbeef,question:.init(name:"invalid",type:1,dnsClass:1)),r=DNSPacket.servFail(for:q);XCTAssertEqual(r.u16(0),0xbeef);XCTAssertEqual(r.u16(2)&0x000f,2)}
}
