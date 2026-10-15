import Foundation
import Network

actor IterativeResolver {
    private struct CacheEntry: Sendable { let response: Data; let expiry: Date }
    private var cache:[DNSQuestion:CacheEntry]=[:]
    private let roots=["198.41.0.4","199.9.14.201","192.33.4.12","199.7.91.13","192.203.230.10","192.5.5.241","192.112.36.4","198.97.190.53","192.36.148.17","192.58.128.30","193.0.14.129","199.7.83.42","202.12.27.33"]

    func resolve(_ request:Data) async throws -> Data {
        let input=try DNSPacket(data:request); guard let question=input.questions.first else { throw DNSError.noQuestion }
        if let hit=cache[question],hit.expiry>Date(){ return withID(hit.response,input.id) }
        cache=cache.filter{$0.value.expiry>Date()}
        var servers=roots
        for _ in 0..<32 {
            guard let server=servers.randomElement() else { throw DNSError.noAnswer }
            let query=DNSPacket.query(id:UInt16.random(in:0...65535),question:question)
            var response=try await exchange(query,server:server,tcp:false), packet=try DNSPacket(data:response)
            if packet.truncated { response=try await exchange(query,server:server,tcp:true); packet=try DNSPacket(data:response) }
            if packet.responseCode != 0 || !packet.answers.isEmpty {
                let positive=packet.answers.map(\.ttl).min(), negative=packet.authorities.filter{$0.type==6}.map(\.ttl).min()
                let ttl=max(5,min(positive ?? negative ?? 30,86400)), final=withID(response,input.id)
                cache[question]=.init(response:withID(final,0),expiry:Date().addingTimeInterval(TimeInterval(ttl))); return final
            }
            let names=packet.authorities.filter{$0.type==2}.compactMap(\.target)
            var next=packet.additionals.compactMap { r -> String? in
                guard names.contains(where:{$0.caseInsensitiveCompare(r.name)==.orderedSame}) else { return nil }
                if r.type==1,r.data.count==4 { return r.data.map(String.init).joined(separator:".") }
                if r.type==28,r.data.count==16 { return stride(from:0,to:16,by:2).map{String(format:"%02x%02x",r.data[$0],r.data[$0+1])}.joined(separator:":") }
                return nil
            }
            if next.isEmpty {
                for ns in names.prefix(2) {
                    if let addresses=try? await resolveNameServer(ns),!addresses.isEmpty { next.append(contentsOf:addresses); break }
                }
            }
            guard !next.isEmpty else { throw DNSError.noAnswer }; servers=next
        }
        throw DNSError.noAnswer
    }

    private func resolveNameServer(_ name:String) async throws->[String]{
        var out:[String]=[]
        for type:UInt16 in [1,28] {
            let q=DNSQuestion(name:name,type:type,dnsClass:1), data=DNSPacket.query(id:1,question:q)
            let response=try await resolve(data), packet=try DNSPacket(data:response)
            for r in packet.answers {
                if r.type==1,r.data.count==4 { out.append(r.data.map(String.init).joined(separator:".")) }
                if r.type==28,r.data.count==16 { out.append(stride(from:0,to:16,by:2).map{String(format:"%02x%02x",r.data[$0],r.data[$0+1])}.joined(separator:":")) }
            }
        }
        return out
    }

    private func exchange(_ query:Data,server:String,tcp:Bool)async throws->Data{
        let connection=NWConnection(host:NWEndpoint.Host(server),port:53,using:tcp ? .tcp:.udp)
        return try await withCheckedThrowingContinuation { continuation in
            let gate=LockedGate()
            func finish(_ result:Result<Data,Error>){ if gate.claim(){ continuation.resume(with:result); connection.cancel() } }
            connection.stateUpdateHandler={ state in
                switch state {
                case .ready:
                    let payload=tcp ? Data([UInt8(query.count>>8),UInt8(query.count&255)])+query : query
                    connection.send(content:payload,completion:.contentProcessed{ error in
                        if let error { finish(.failure(error)); return }
                        if tcp { receiveTCP(connection,finish:finish) }
                        else { connection.receiveMessage { data,_,_,error in if let error { finish(.failure(error)) } else if let data { finish(.success(data)) } else { finish(.failure(DNSError.network)) } } }
                    })
                case .failed(let error): finish(.failure(error))
                case .cancelled: break
                default: break
                }
            }
            connection.start(queue:DispatchQueue.global(qos:.userInitiated))
            DispatchQueue.global().asyncAfter(deadline:.now()+5){ finish(.failure(DNSError.timeout)) }
        }
    }

    private func withID(_ data:Data,_ id:UInt16)->Data{ var d=data; guard d.count>=2 else{return d}; d[0]=UInt8(id>>8); d[1]=UInt8(id&255); return d }
}

private final class LockedGate: @unchecked Sendable { private let lock=NSLock(); private var used=false; func claim()->Bool{ lock.lock(); defer{lock.unlock()}; guard !used else{return false}; used=true; return true } }
private func receiveTCP(_ connection:NWConnection,finish:@escaping(Result<Data,Error>)->Void){
    connection.receive(minimumIncompleteLength:2,maximumLength:2){ header,_,_,error in
        if let error{finish(.failure(error));return}; guard let header,header.count==2 else{finish(.failure(DNSError.invalidPacket));return}
        let length=Int(header[0])<<8|Int(header[1]); receiveExact(connection,remaining:length,buffer:Data(),finish:finish)
    }
}
private func receiveExact(_ connection:NWConnection,remaining:Int,buffer:Data,finish:@escaping(Result<Data,Error>)->Void){
    if remaining==0{finish(.success(buffer));return}
    connection.receive(minimumIncompleteLength:1,maximumLength:remaining){ data,_,_,error in
        if let error{finish(.failure(error));return}; guard let data,!data.isEmpty else{finish(.failure(DNSError.network));return}; receiveExact(connection,remaining:remaining-data.count,buffer:buffer+data,finish:finish)
    }
}
