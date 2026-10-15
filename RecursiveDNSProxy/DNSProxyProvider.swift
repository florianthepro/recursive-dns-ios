import Network
import NetworkExtension

final class DNSProxyProvider: NEDNSProxyProvider {
    private let resolver = IterativeResolver()

    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Task { await resolver.cancel() }
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        if let udp = flow as? NEAppProxyUDPFlow {
            handleUDP(udp)
            return true
        }
        if let tcp = flow as? NEAppProxyTCPFlow {
            handleTCP(tcp)
            return true
        }
        return false
    }

    private func handleUDP(_ flow: NEAppProxyUDPFlow) {
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard error == nil, let self else { flow.closeReadWithError(error); flow.closeWriteWithError(error); return }
            self.readUDP(flow)
        }
    }

    private func readUDP(_ flow: NEAppProxyUDPFlow) {
        flow.readDatagrams { [weak self] datagrams, endpoints, error in
            guard let self, error == nil, let datagrams, let endpoints else {
                flow.closeReadWithError(error); flow.closeWriteWithError(error); return
            }
            Task {
                var replies: [Data] = []
                var replyEndpoints: [NWEndpoint] = []
                for (index, query) in datagrams.enumerated() {
                    if let response = try? await self.resolver.resolve(query) {
                        replies.append(response)
                        replyEndpoints.append(endpoints[index])
                    }
                }
                if !replies.isEmpty {
                    flow.writeDatagrams(replies, sentBy: replyEndpoints) { _ in }
                }
                self.readUDP(flow)
            }
        }
    }

    private func handleTCP(_ flow: NEAppProxyTCPFlow) {
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard error == nil, let self else { flow.closeReadWithError(error); flow.closeWriteWithError(error); return }
            self.readTCP(flow, buffer: Data())
        }
    }

    private func readTCP(_ flow: NEAppProxyTCPFlow, buffer: Data) {
        flow.readData { [weak self] data, error in
            guard let self, error == nil, let data, !data.isEmpty else {
                flow.closeReadWithError(error); flow.closeWriteWithError(error); return
            }
            var pending = buffer + data
            Task {
                while pending.count >= 2 {
                    let length = Int(pending[0]) << 8 | Int(pending[1])
                    guard pending.count >= length + 2 else { break }
                    let query = pending.subdata(in: 2..<(length + 2))
                    pending.removeSubrange(0..<(length + 2))
                    if let response = try? await self.resolver.resolve(query) {
                        var framed = Data([UInt8(response.count >> 8), UInt8(response.count & 255)])
                        framed.append(response)
                        try? await self.writeTCP(flow, framed)
                    }
                }
                self.readTCP(flow, buffer: pending)
            }
        }
    }

    private func writeTCP(_ flow: NEAppProxyTCPFlow, _ data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            flow.write(data) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
