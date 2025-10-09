import Foundation

enum DumpFileStore {
    private static let key = "DumpUndump.SelectedDumpFileBookmark.v1"

    static func save(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            NSLog("DumpFileStore.save error: \(error.localizedDescription)")
        }
    }

    static func load() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale { save(url) }
            return url
        } catch {
            NSLog("DumpFileStore.load error: \(error.localizedDescription)")
            return nil
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
