import SwiftUI

@main
struct RecursiveDNSApp: App {
    @StateObject private var model = DNSProxyModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model)
        }
    }
}
