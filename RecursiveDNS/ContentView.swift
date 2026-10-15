import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DNSProxyModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: model.enabled ? "network.badge.shield.half.filled" : "network")
                    .font(.system(size: 72))
                    .foregroundStyle(model.enabled ? .green : .secondary)
                Text(model.enabled ? "Rekursive DNS-Auflösung aktiv" : "Rekursive DNS-Auflösung inaktiv")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Toggle("DNS lokal rekursiv auflösen", isOn: Binding(
                    get: { model.enabled },
                    set: { model.setEnabled($0) }
                ))
                .disabled(model.busy)
                if let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Spacer()
                Text("Kein externer rekursiver Resolver. Kein VPN. Keine Telemetrie.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(24)
            .navigationTitle("Recursive DNS")
            .task { await model.reload() }
        }
    }
}
