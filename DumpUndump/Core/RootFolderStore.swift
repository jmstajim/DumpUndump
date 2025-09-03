import Foundation

enum RootFolderStore {
    private static let key = "DumpUndump.RootFolderBookmark.v1"

    static func save(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            NSLog("RootFolderStore.save error: \(error.localizedDescription)")
        }
    }

    static func load() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if isStale {
                save(url)
            }
            return url
        } catch {
            NSLog("RootFolderStore.load error: \(error.localizedDescription)")
            return nil
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

