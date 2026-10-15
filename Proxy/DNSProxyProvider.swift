import Foundation
import Network
import NetworkExtension

final class DNSProxyProvider: NEDNSProxyProvider {
    private let resolver=IterativeResolver()
    override func startProxy(options:[String:Any]?=nil,completionHandler:@escaping(Error?)->Void){ completionHandler(nil) }
    override func stopProxy(with reason:NEProviderStopReason,completionHandler:@escaping()->Void){ completionHandler() }

    override func handleNewFlow(_ flow:NEAppProxyFlow)->Bool{
        if let udp=flow as? NEAppProxyUDPFlow { openUDP(udp); return true }
        if let tcp=flow as? NEAppProxyTCPFlow { openTCP(tcp); return true }
        return false
    }

    private func answer(_ request:Data)async->Data{
        guard SharedPreferences.defaults.bool(forKey:SharedPreferences.resolverEnabledKey) else{return DNSPacket.servFail(for:request)}
        SharedPreferences.defaults.set(Date(),forKey:SharedPreferences.lastQueryKey)
        return (try? await resolver.resolve(request)) ?? DNSPacket.servFail(for:request)
    }
    private func openUDP(_ flow:NEAppProxyUDPFlow){ flow.open(withLocalEndpoint:nil){[weak self] error in guard error==nil,let self else{flow.closeReadWithError(error);flow.closeWriteWithError(error);return};self.readUDP(flow)} }
    private func readUDP(_ flow:NEAppProxyUDPFlow){ flow.readDatagrams{[weak self] packets,endpoints,error in guard let self,error==nil,let packets,let endpoints else{flow.closeReadWithError(error);flow.closeWriteWithError(error);return};Task{var replies:[Data]=[];for packet in packets{replies.append(await self.answer(packet))};flow.writeDatagrams(replies,sentBy:endpoints){_ in};self.readUDP(flow)}} }
    private func openTCP(_ flow:NEAppProxyTCPFlow){ flow.open(withLocalEndpoint:nil){[weak self] error in guard error==nil,let self else{flow.closeReadWithError(error);flow.closeWriteWithError(error);return};self.readTCP(flow,buffer:Data())} }
    private func readTCP(_ flow:NEAppProxyTCPFlow,buffer:Data){ flow.readData{[weak self] data,error in guard let self,error==nil,let data,!data.isEmpty else{flow.closeReadWithError(error);flow.closeWriteWithError(error);return};Task{var pending=buffer+data;while pending.count>=2{let length=Int(pending[0])<<8|Int(pending[1]);guard pending.count>=length+2 else{break};let query=pending.subdata(in:2..<(length+2));pending.removeSubrange(0..<(length+2));let response=await self.answer(query),framed=Data([UInt8(response.count>>8),UInt8(response.count&255)])+response;await self.write(flow,framed)};self.readTCP(flow,buffer:pending)}} }
    private func write(_ flow:NEAppProxyTCPFlow,_ data:Data)async{ await withCheckedContinuation{ continuation in flow.write(data){_ in continuation.resume()} } }
}
