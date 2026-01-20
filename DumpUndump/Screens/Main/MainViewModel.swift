import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    private let dump: DumpProtocol
    private let undump: UndumpProtocol
    private let optionsStore: OptionsStore
    private let rootFolderStore: BookmarkStore
    private let dumpFileStore: BookmarkStore
    private let fileDialog: FileDialog
    private let folderPicker: FolderPickerType
    private let clipboard: ClipboardService
    private let dateStamp: DateStampProvider
    private let dumpWatcher: FileChangeWatcher

    @Published var rootFolder: URL?
    @Published var options: DumpOptions = .default
    @Published var dumpText: String = ""
    @Published var dryRun: Bool = false
    @Published var makeBackups: Bool = false
    @Published var isWorking: Bool = false
    @Published var dumpReport: String = ""
    @Published var undumpReport: String = ""
    @Published var errorAlert: AppErrorAlert?
    @Published var selectedDumpURL: URL? {
        didSet { configureDumpWatcher() }
    }
    @Published var autoLoadDump: Bool {
        didSet {
            UserDefaults.standard.set(autoLoadDump, forKey: Self.autoLoadKey)
            configureDumpWatcher()
        }
    }
    @Published var autoApply: Bool {
        didSet {
            UserDefaults.standard.set(autoApply, forKey: Self.autoApplyKey)
        }
    }

    private static let autoLoadKey = "DumpUndump.AutoLoadDump.v1"
    private static let autoApplyKey = "DumpUndump.AutoApplyDump.v1"

    init(
        dump: DumpProtocol = DumpService(),
        undump: UndumpProtocol = UndumpService(),
        optionsStore: OptionsStore = SettingsStoreService(),
        rootFolderStore: BookmarkStore = RootFolderBookmarkStore(),
        dumpFileStore: BookmarkStore = DumpFileBookmarkStore(),
        fileDialog: FileDialog = FilePanelService(),
        folderPicker: FolderPickerType = FolderPickerService(),
        clipboard: ClipboardService = PasteboardService(),
        dateStamp: DateStampProvider = ISODateStampProvider(),
        dumpWatcher: FileChangeWatcher = DefaultFileChangeWatcher()
    ) {
        self.dump = dump
        self.undump = undump
        self.optionsStore = optionsStore
        self.rootFolderStore = rootFolderStore
        self.dumpFileStore = dumpFileStore
        self.fileDialog = fileDialog
        self.folderPicker = folderPicker
        self.clipboard = clipboard
        self.dateStamp = dateStamp
        self.dumpWatcher = dumpWatcher

        self.options = optionsStore.load() ?? .default
        self.rootFolder = rootFolderStore.load()
        self.selectedDumpURL = dumpFileStore.load()
        self.autoLoadDump = UserDefaults.standard.object(forKey: Self.autoLoadKey) as? Bool ?? false
        self.autoApply = UserDefaults.standard.object(forKey: Self.autoApplyKey) as? Bool ?? false

        configureDumpWatcher()
    }

    deinit {
        dumpWatcher.stop()
    }

    func pickRootFolder() {
        if let url = folderPicker.pickFolder() {
            rootFolderStore.save(url)
            rootFolder = url
        }
    }

    func generateDump() {
        guard let root = rootFolder else { return }
        isWorking = true
        dumpReport = ""
        let options = self.options
        Task.detached { [weak self] in
            guard let self else { return }
            let needsAccess = root.startAccessingSecurityScopedResource()
            defer { if needsAccess { root.stopAccessingSecurityScopedResource() } }
            do {
                let result = try await self.dump.dump(root: root, options: options)
                await MainActor.run {
                    self.dumpText = result.text
                    self.dumpReport = "Files included: \(result.filesCount) • Output size: \(ByteCountFormatter.string(fromByteCount: Int64(result.text.utf8.count), countStyle: .file))"
                    self.isWorking = false
                }
            } catch {
                await MainActor.run {
                    self.isWorking = false
                    self.errorAlert = AppErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    func copyDumpToClipboard() {
        guard !dumpText.isEmpty else { return }
        clipboard.copyString(dumpText)
    }

    func copyDumpAsFileToPasteboard() {
        guard !dumpText.isEmpty else { return }
        guard let rootFolderName = rootFolder?.lastPathComponent else { return }
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = "\(rootFolderName)_dump_\(dateStamp.stamp()).txt"
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try dumpText.write(to: fileURL, atomically: true, encoding: .utf8)
            let ok = clipboard.copyFileURL(fileURL)
            if !ok {
                errorAlert = AppErrorAlert(message: "Failed to copy the file to the clipboard.")
            }
        } catch {
            errorAlert = AppErrorAlert(message: error.localizedDescription)
        }
    }

    func saveDumpToFile() {
        guard !dumpText.isEmpty else { return }
        guard let rootFolderName = rootFolder?.lastPathComponent else { return }
        if let url = fileDialog.saveText(suggestedName: "\(rootFolderName)_dump_\(dateStamp.stamp()).txt") {
            do { try dumpText.write(to: url, atomically: true, encoding: .utf8) } catch {
                errorAlert = AppErrorAlert(message: error.localizedDescription)
            }
        }
    }

    func loadDumpFromFile() {
        if let url = fileDialog.openText() {
            do { dumpText = try String(contentsOf: url, encoding: .utf8) } catch {
                errorAlert = AppErrorAlert(message: error.localizedDescription)
            }
        }
    }

    func pickDumpFileForLoading() {
        if let url = fileDialog.openText() {
            dumpFileStore.save(url)
            selectedDumpURL = url
        }
    }

    func clearSelectedDumpFile() {
        dumpFileStore.clear()
        selectedDumpURL = nil
    }

    func loadDumpFromSelectedPath() {
        guard let url = selectedDumpURL else { return }
        loadDump(from: url)
    }

    func applyDumpToFolder() {
        guard let root = rootFolder, !dumpText.isEmpty else { return }
        isWorking = true
        undumpReport = ""
        let dryRun = self.dryRun
        let makeBackups = self.makeBackups
        let text = self.dumpText
        Task.detached { [weak self] in
            guard let self else { return }
            let needsAccess = root.startAccessingSecurityScopedResource()
            defer { if needsAccess { root.stopAccessingSecurityScopedResource() } }
            do {
                let report = try await self.undump.undump(text: text, toRoot: root, dryRun: dryRun, makeBackups: makeBackups)
                await MainActor.run {
                    self.undumpReport = Self.formatUndumpReport(report)
                    self.isWorking = false
                }
            } catch {
                await MainActor.run {
                    self.isWorking = false
                    self.errorAlert = AppErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    func loadOptions() {
        options = optionsStore.load() ?? .default
    }

    func saveOptions() {
        optionsStore.save(options)
    }

    func resetOptions() {
        options = .default
        optionsStore.save(options)
    }

    private func configureDumpWatcher() {
        dumpWatcher.stop()
        guard autoLoadDump, let url = selectedDumpURL else { return }
        dumpWatcher.start(url: url) { [weak self] in
            guard let self else { return }
            self.loadDumpFromSelectedPath()
            if self.autoApply {
                self.applyDumpToFolder()
            }
        }
    }

    private func loadDump(from url: URL) {
        let needs = url.startAccessingSecurityScopedResource()
        defer { if needs { url.stopAccessingSecurityScopedResource() } }
        do {
            dumpText = try String(contentsOf: url, encoding: .utf8)
        } catch {
            errorAlert = AppErrorAlert(message: error.localizedDescription)
        }
    }
    private static func formatUndumpReport(_ report: UndumpReport) -> String {
        var lines: [String] = []
        if !report.summary.isEmpty {
            lines.append(report.summary)
        }

        if !report.failed.isEmpty {
            lines.append("Failed paths:")
            for p in report.failed.prefix(20) {
                lines.append("• \(p)")
            }
            if report.failed.count > 20 {
                lines.append("• …and \(report.failed.count - 20) more")
            }
        }

        if !report.issues.isEmpty {
            lines.append("Issues:")
            for issue in report.issues.prefix(20) {
                lines.append("• \(issue.path): \(issue.message)")
            }
            if report.issues.count > 20 {
                lines.append("• …and \(report.issues.count - 20) more")
            }
        }

        return lines.joined(separator: "\n")
    }

}

struct AppErrorAlert: Identifiable { let id = UUID(); let message: String }
