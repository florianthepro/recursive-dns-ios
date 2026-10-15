import Foundation

struct DNSQuestion: Hashable, Sendable { let name: String; let type: UInt16; let dnsClass: UInt16 }
struct DNSRecord: Sendable { let name: String; let type: UInt16; let dnsClass: UInt16; let ttl: UInt32; let data: Data; let target: String? }

enum DNSError: Error { case invalidPacket, noQuestion, noAnswer, timeout, network }

struct DNSPacket: Sendable {
    let id: UInt16, flags: UInt16
    let questions: [DNSQuestion], answers: [DNSRecord], authorities: [DNSRecord], additionals: [DNSRecord]
    var truncated: Bool { flags & 0x0200 != 0 }
    var responseCode: UInt16 { flags & 0x000f }

    init(data: Data) throws {
        guard data.count >= 12 else { throw DNSError.invalidPacket }
        id=data.u16(0); flags=data.u16(2)
        let counts=[data.u16(4),data.u16(6),data.u16(8),data.u16(10)].map(Int.init)
        var offset=12, qs:[DNSQuestion]=[]
        for _ in 0..<counts[0] {
            let name=try data.readName(&offset)
            guard offset+4 <= data.count else { throw DNSError.invalidPacket }
            qs.append(.init(name:name.lowercased(), type:data.u16(offset), dnsClass:data.u16(offset+2))); offset += 4
        }
        questions=qs
        func records(_ count:Int, _ data:Data, _ offset:inout Int) throws -> [DNSRecord] {
            var out:[DNSRecord]=[]
            for _ in 0..<count {
                let name=try data.readName(&offset).lowercased()
                guard offset+10 <= data.count else { throw DNSError.invalidPacket }
                let type=data.u16(offset), cls=data.u16(offset+2), ttl=data.u32(offset+4), length=Int(data.u16(offset+8)); offset += 10
                guard offset+length <= data.count else { throw DNSError.invalidPacket }
                let start=offset, bytes=data.subdata(in:start..<(start+length)); var nameOffset=start
                let target=[2,5,12].contains(Int(type)) ? try? data.readName(&nameOffset).lowercased() : nil
                out.append(.init(name:name,type:type,dnsClass:cls,ttl:ttl,data:bytes,target:target)); offset += length
            }
            return out
        }
        answers=try records(counts[1],data,&offset); authorities=try records(counts[2],data,&offset); additionals=try records(counts[3],data,&offset)
    }

    static func query(id:UInt16, question:DNSQuestion) -> Data {
        var d=Data(); [id,0,1,0,0,1].forEach { d.put($0) }; d.putName(question.name); d.put(question.type); d.put(question.dnsClass)
        d.put(UInt16(0)); d.put(UInt16(41)); d.put(UInt16(1232)); d.put(UInt32(0)); d.put(UInt16(0)); return d
    }

    static func servFail(for request:Data) -> Data {
        var d=request
        guard d.count >= 12 else { return Data() }
        let requestFlags=d.u16(2), flags:UInt16=0x8000 | (requestFlags & 0x0100) | 0x0002
        d[2]=UInt8(flags >> 8); d[3]=UInt8(flags & 255); for i in 6..<12 { d[i]=0 }; return d
    }
}

extension Data {
    func u16(_ i:Int)->UInt16 { UInt16(self[i])<<8 | UInt16(self[i+1]) }
    func u32(_ i:Int)->UInt32 { UInt32(u16(i))<<16 | UInt32(u16(i+2)) }
    mutating func put(_ v:UInt16){ append(UInt8(v>>8)); append(UInt8(v&255)) }
    mutating func put(_ v:UInt32){ put(UInt16(v>>16)); put(UInt16(v&65535)) }
    mutating func putName(_ name:String){ for label in name.split(separator:"."){ append(UInt8(label.utf8.count)); append(contentsOf:label.utf8) }; append(0) }
    func readName(_ offset:inout Int)throws->String{
        var labels:[String]=[], cursor=offset, jumped=false, visited=Set<Int>()
        while true {
            guard cursor<count, visited.insert(cursor).inserted else { throw DNSError.invalidPacket }
            let length=Int(self[cursor]); if length==0 { if !jumped { offset=cursor+1 }; break }
            if length & 0xc0 == 0xc0 { guard cursor+1<count else { throw DNSError.invalidPacket }; let p=(length&0x3f)<<8|Int(self[cursor+1]); if !jumped { offset=cursor+2; jumped=true }; cursor=p }
            else { cursor += 1; guard length<=63,cursor+length<=count,let label=String(data:self[cursor..<(cursor+length)],encoding:.utf8) else { throw DNSError.invalidPacket }; labels.append(label); cursor += length; if !jumped { offset=cursor } }
        }
        return labels.joined(separator:".")
    }
}
