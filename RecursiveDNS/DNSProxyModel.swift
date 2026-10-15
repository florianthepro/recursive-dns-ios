import Foundation
import NetworkExtension

@MainActor
final class DNSProxyModel: ObservableObject {
    @Published var enabled = false
    @Published var busy = false
    @Published var message: String?
    private let manager = NEDNSProxyManager.shared()

    func reload() async {
        busy = true
        defer { busy = false }
        do {
            try await manager.loadFromPreferences()
            enabled = manager.isEnabled
            message = enabled ? nil : "Zum Betrieb muss das DNS-Proxy-Profil auf diesem Gerät installiert sein."
        } catch {
            message = error.localizedDescription
        }
    }

    func setEnabled(_ value: Bool) {
        Task { await apply(value) }
    }

    private func apply(_ value: Bool) async {
        busy = true
        defer { busy = false }
        do {
            try await manager.loadFromPreferences()
            if manager.providerProtocol == nil {
                let proto = NEDNSProxyProviderProtocol()
                proto.providerBundleIdentifier = "de.florianthepro.recursivedns.proxy"
                manager.providerProtocol = proto
                manager.localizedDescription = "Recursive DNS"
            }
            manager.isEnabled = value
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            enabled = manager.isEnabled
            message = nil
        } catch {
            enabled = manager.isEnabled
            message = error.localizedDescription
        }
    }
}
