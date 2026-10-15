import Foundation

struct DNSQuestion: Hashable {
    let name: String
    let type: UInt16
    let dnsClass: UInt16
}

struct DNSRecord {
    let name: String
    let type: UInt16
    let dnsClass: UInt16
    let ttl: UInt32
    let data: Data
    let target: String?
}

struct DNSPacket {
    let id: UInt16
    let flags: UInt16
    let questions: [DNSQuestion]
    let answers: [DNSRecord]
    let authorities: [DNSRecord]
    let additionals: [DNSRecord]

    var truncated: Bool { flags & 0x0200 != 0 }
    var responseCode: UInt16 { flags & 0x000F }

    init(data: Data) throws {
        guard data.count >= 12 else { throw DNSError.invalidPacket }
        id = data.u16(0); flags = data.u16(2)
        let counts = [data.u16(4), data.u16(6), data.u16(8), data.u16(10)].map(Int.init)
        var offset = 12
        var qs: [DNSQuestion] = []
        for _ in 0..<counts[0] {
            let name = try data.readName(&offset)
            guard offset + 4 <= data.count else { throw DNSError.invalidPacket }
            qs.append(DNSQuestion(name: name, type: data.u16(offset), dnsClass: data.u16(offset + 2)))
            offset += 4
        }
        questions = qs
        func readRecords(_ count: Int, _ data: Data, _ offset: inout Int) throws -> [DNSRecord] {
            var result: [DNSRecord] = []
            for _ in 0..<count {
                let name = try data.readName(&offset)
                guard offset + 10 <= data.count else { throw DNSError.invalidPacket }
                let type = data.u16(offset), cls = data.u16(offset + 2), ttl = data.u32(offset + 4), length = Int(data.u16(offset + 8))
                offset += 10
                guard offset + length <= data.count else { throw DNSError.invalidPacket }
                let start = offset
                let bytes = data.subdata(in: offset..<(offset + length))
                var targetOffset = start
                let target = [2, 5, 12].contains(Int(type)) ? try? data.readName(&targetOffset) : nil
                result.append(DNSRecord(name: name, type: type, dnsClass: cls, ttl: ttl, data: bytes, target: target))
                offset += length
            }
            return result
        }
        answers = try readRecords(counts[1], data, &offset)
        authorities = try readRecords(counts[2], data, &offset)
        additionals = try readRecords(counts[3], data, &offset)
    }

    static func query(id: UInt16, question: DNSQuestion) -> Data {
        var data = Data()
        data.put(id); data.put(UInt16(0)); data.put(UInt16(1)); data.put(UInt16(0)); data.put(UInt16(0)); data.put(UInt16(0))
        data.putName(question.name); data.put(question.type); data.put(question.dnsClass)
        return data
    }
}

enum DNSError: Error { case invalidPacket, noQuestion, noAnswer, timeout, network }

extension Data {
    func u16(_ i: Int) -> UInt16 { UInt16(self[i]) << 8 | UInt16(self[i + 1]) }
    func u32(_ i: Int) -> UInt32 { UInt32(u16(i)) << 16 | UInt32(u16(i + 2)) }
    mutating func put(_ value: UInt16) { append(UInt8(value >> 8)); append(UInt8(value & 255)) }
    mutating func put(_ value: UInt32) { put(UInt16(value >> 16)); put(UInt16(value & 65535)) }
    mutating func putName(_ name: String) {
        for label in name.split(separator: ".") { append(UInt8(label.utf8.count)); append(contentsOf: label.utf8) }
        append(0)
    }
    func readName(_ offset: inout Int) throws -> String {
        var labels: [String] = [], cursor = offset, jumped = false, visited: Set<Int> = []
        while true {
            guard cursor < count, !visited.contains(cursor) else { throw DNSError.invalidPacket }
            visited.insert(cursor)
            let length = Int(self[cursor])
            if length == 0 { if !jumped { offset = cursor + 1 }; break }
            if length & 0xC0 == 0xC0 {
                guard cursor + 1 < count else { throw DNSError.invalidPacket }
                let pointer = (length & 0x3F) << 8 | Int(self[cursor + 1])
                if !jumped { offset = cursor + 2; jumped = true }
                cursor = pointer
            } else {
                cursor += 1
                guard length <= 63, cursor + length <= count, let label = String(data: self[cursor..<(cursor + length)], encoding: .utf8) else { throw DNSError.invalidPacket }
                labels.append(label); cursor += length
                if !jumped { offset = cursor }
            }
        }
        return labels.joined(separator: ".")
    }
}
