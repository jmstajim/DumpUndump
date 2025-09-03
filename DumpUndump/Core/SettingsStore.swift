import Foundation

enum SettingsStore {
    private static let key = "DumpUndump.DumpOptions.v1"

    static func save(_ options: DumpOptions) {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> DumpOptions? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DumpOptions.self, from: data)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

