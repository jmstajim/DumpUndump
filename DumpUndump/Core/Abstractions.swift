import Foundation

protocol DumpProtocol {
    func dump(root: URL, options: DumpOptions) throws -> DumpResult
}

protocol UndumpProtocol {
    func undump(text: String, toRoot root: URL, dryRun: Bool, makeBackups: Bool) throws -> UndumpReport
}

protocol OptionsStore {
    func save(_ options: DumpOptions)
    func load() -> DumpOptions?
    func reset()
}

protocol BookmarkStore {
    func save(_ url: URL)
    func load() -> URL?
    func clear()
}

protocol FileDialog {
    func saveText(suggestedName: String) -> URL?
    func openText() -> URL?
}

protocol FolderPickerType {
    func pickFolder() -> URL?
}

protocol ClipboardService {
    func copyString(_ s: String)
    func copyFileURL(_ url: URL) -> Bool
}

protocol DateStampProvider {
    func stamp() -> String
}

protocol FileChangeWatcher {
    func start(url: URL, onChange: @escaping () -> Void)
    func stop()
}

