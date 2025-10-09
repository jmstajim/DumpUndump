import AppKit

struct DumpService: DumpProtocol {
    func dump(root: URL, options: DumpOptions) throws -> DumpResult {
        try Dump.dump(root: root, options: options)
    }
}

struct UndumpService: UndumpProtocol {
    func undump(text: String, toRoot root: URL, dryRun: Bool, makeBackups: Bool) throws -> UndumpReport {
        try Undump.undump(text: text, toRoot: root, dryRun: dryRun, makeBackups: makeBackups)
    }
}

struct SettingsStoreService: OptionsStore {
    func save(_ options: DumpOptions) { SettingsStore.save(options) }
    func load() -> DumpOptions? { SettingsStore.load() }
    func reset() { SettingsStore.reset() }
}

struct RootFolderBookmarkStore: BookmarkStore {
    func save(_ url: URL) { RootFolderStore.save(url) }
    func load() -> URL? { RootFolderStore.load() }
    func clear() { RootFolderStore.clear() }
}

struct DumpFileBookmarkStore: BookmarkStore {
    func save(_ url: URL) { DumpFileStore.save(url) }
    func load() -> URL? { DumpFileStore.load() }
    func clear() { DumpFileStore.clear() }
}

struct FilePanelService: FileDialog {
    func saveText(suggestedName: String) -> URL? { FilePanel.saveText(suggestedName: suggestedName) }
    func openText() -> URL? { FilePanel.openText() }
}

struct FolderPickerService: FolderPickerType {
    func pickFolder() -> URL? { FolderPicker.pickFolder() }
}

struct PasteboardService: ClipboardService {
    func copyString(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
    func copyFileURL(_ url: URL) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.writeObjects([url as NSURL])
    }
}

struct ISODateStampProvider: DateStampProvider {
    func stamp() -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return iso.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }
}
