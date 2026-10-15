import Foundation
import Network

actor IterativeResolver {
    struct CacheEntry { let response: Data; let expires: Date }
    private var cache: [DNSQuestion: CacheEntry] = [:]
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "de.florianthepro.recursivedns.resolver")
    private let roots = ["198.41.0.4", "199.9.14.201", "192.33.4.12", "199.7.91.13", "192.203.230.10", "192.5.5.241", "192.112.36.4", "198.97.190.53", "192.36.148.17", "192.58.128.30", "193.0.14.129", "199.7.83.42", "202.12.27.33"]

    func cancel() {
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    func resolve(_ request: Data) async throws -> Data {
        let incoming = try DNSPacket(data: request)
        guard let question = incoming.questions.first else { throw DNSError.noQuestion }
        if let hit = cache[question], hit.expires > Date() {
            return rewriteID(hit.response, incoming.id)
        }
        var servers = roots
        var current = question
        var seen: Set<String> = []
        for _ in 0..<32 {
            guard let server = servers.randomElement() else { throw DNSError.noAnswer }
            var response = try await exchange(DNSPacket.query(id: UInt16.random(in: 0...65535), question: current), server: server, tcp: false)
            var packet = try DNSPacket(data: response)
            if packet.truncated {
                response = try await exchange(DNSPacket.query(id: UInt16.random(in: 0...65535), question: current), server: server, tcp: true)
                packet = try DNSPacket(data: response)
            }
            if packet.responseCode != 0 || !packet.answers.isEmpty {
                if let cname = packet.answers.first(where: { $0.type == 5 })?.target, packet.answers.first(where: { $0.type == question.type }) == nil {
                    guard seen.insert(cname).inserted else { throw DNSError.noAnswer }
                    current = DNSQuestion(name: cname, type: question.type, dnsClass: question.dnsClass)
                    servers = roots
                    continue
                }
                let ttl = packet.answers.map(\.ttl).min() ?? 30
                let final = rewriteQuestionAndID(response, request: request, id: incoming.id)
                cache[question] = CacheEntry(response: rewriteID(final, 0), expires: Date().addingTimeInterval(TimeInterval(max(5, min(ttl, 86400)))))
                return final
            }
            let nsNames = packet.authorities.filter { $0.type == 2 }.compactMap(\.target)
            var glue: [String] = []
            for record in packet.additionals where nsNames.contains(where: { $0.caseInsensitiveCompare(record.name) == .orderedSame }) {
                if record.type == 1, record.data.count == 4 { glue.append(record.data.map(String.init).joined(separator: ".")) }
                if record.type == 28, record.data.count == 16 { glue.append(ipv6(record.data)) }
            }
            if glue.isEmpty, let ns = nsNames.first {
                let nsQuestion = DNSQuestion(name: ns, type: 1, dnsClass: 1)
                let nsResponse = try await resolve(DNSPacket.query(id: 1, question: nsQuestion))
                let nsPacket = try DNSPacket(data: nsResponse)
                glue = nsPacket.answers.filter { $0.type == 1 && $0.data.count == 4 }.map { $0.data.map(String.init).joined(separator: ".") }
            }
            guard !glue.isEmpty else { throw DNSError.noAnswer }
            servers = glue
        }
        throw DNSError.noAnswer
    }

    private func exchange(_ query: Data, server: String, tcp: Bool) async throws -> Data {
        let host = NWEndpoint.Host(server), port = NWEndpoint.Port(rawValue: 53)!
        let connection = NWConnection(host: host, port: port, using: tcp ? .tcp : .udp)
        connections.append(connection)
        defer { connection.cancel(); connections.removeAll { $0 === connection } }
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            func finish(_ result: Result<Data, Error>) {
                guard !finished else { return }; finished = true; continuation.resume(with: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var payload = query
                    if tcp { payload = Data([UInt8(query.count >> 8), UInt8(query.count & 255)]) + query }
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error { finish(.failure(error)); return }
                        connection.receive(minimumIncompleteLength: tcp ? 2 : 1, maximumLength: 65535) { data, _, _, error in
                            if let error { finish(.failure(error)); return }
                            guard var data else { finish(.failure(DNSError.network)); return }
                            if tcp {
                                guard data.count >= 2 else { finish(.failure(DNSError.invalidPacket)); return }
                                let length = Int(data[0]) << 8 | Int(data[1])
                                data.removeFirst(2)
                                guard data.count >= length else { finish(.failure(DNSError.invalidPacket)); return }
                                data = Data(data.prefix(length))
                            }
                            finish(.success(data))
                        }
                    })
                case .failed(let error): finish(.failure(error))
                case .cancelled: finish(.failure(DNSError.network))
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 4) { finish(.failure(DNSError.timeout)); connection.cancel() }
        }
    }

    private func rewriteID(_ data: Data, _ id: UInt16) -> Data {
        var result = data
        guard result.count >= 2 else { return data }
        result[0] = UInt8(id >> 8); result[1] = UInt8(id & 255)
        return result
    }

    private func rewriteQuestionAndID(_ response: Data, request: Data, id: UInt16) -> Data {
        rewriteID(response, id)
    }

    private func ipv6(_ data: Data) -> String {
        stride(from: 0, to: 16, by: 2).map { String(format: "%02x%02x", data[$0], data[$0 + 1]) }.joined(separator: ":")
    }
}
