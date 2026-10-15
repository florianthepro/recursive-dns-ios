import SwiftUI

struct ContentView: View {
    @AppStorage(SharedPreferences.resolverEnabledKey, store: SharedPreferences.defaults) private var enabled = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastQuery: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image("BrandMark")
                        .resizable().scaledToFit().frame(width: 118, height: 118)
                        .accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Text("Recursive DNS").font(.largeTitle.bold())
                        Text("Lokale, iterative DNS-Auflösung")
                            .foregroundStyle(.secondary)
                    }
                    statusCard
                    Toggle(isOn: $enabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Resolver aktiv").font(.headline)
                            Text("Verarbeitet DNS-Anfragen lokal über die Network Extension.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Kein externer rekursiver Resolver", systemImage: "network")
                        Label("Kein VPN und kein belegter VPN-Slot", systemImage: "shield.slash")
                        Label("Keine Konten, Werbung oder Telemetrie", systemImage: "hand.raised")
                    }
                    .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    Link("Support und Datenschutz", destination: URL(string: "https://florianthepro.github.io/recursive-dns/")!)
                        .font(.footnote)
                }
                .padding(22)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: enabled ? "checkmark.shield.fill" : "pause.circle.fill")
                .font(.system(size: 32)).foregroundStyle(enabled ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(enabled ? "Bereit" : "Pausiert").font(.headline)
                Text(lastQuery.map { "Letzte DNS-Anfrage: \($0.formatted(date: .omitted, time: .standard))" } ?? "Noch keine DNS-Anfrage erfasst")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18).background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func refresh() {
        lastQuery = SharedPreferences.defaults.object(forKey: SharedPreferences.lastQueryKey) as? Date
    }
}
