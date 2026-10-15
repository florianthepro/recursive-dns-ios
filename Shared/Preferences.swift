import Foundation

enum SharedPreferences {
    static let appGroup = "group.de.floriankutzer.recursivedns"
    static let resolverEnabledKey = "resolverEnabled"
    static let lastQueryKey = "lastQueryDate"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}
