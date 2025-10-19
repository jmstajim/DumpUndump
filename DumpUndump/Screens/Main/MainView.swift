import SwiftUI

struct MainView: View {
    @StateObject private var vm = MainViewModel()
    @AppStorage("DumpUndump.ChatPrompt.v1") private var prompt: String = ""
    @State private var dumpLines: Int = 0
    @State private var dumpBytes: Int = 0
    @State private var dumpSizeString: String = ""
    @State private var dumpTokens: Int = 0
    @State private var optionsSaveWork: DispatchWorkItem?

    var body: some View {
        NavigationSplitView {
            List {
                RootFolderSectionView(
                    path: vm.rootFolder?.path ?? "No folder selected",
                    onPick: vm.pickRootFolder
                )
                DumpSectionView(
                    options: $vm.options,
                    isWorking: vm.isWorking,
                    dumpReport: vm.dumpReport,
                    isGenerateDisabled: vm.rootFolder == nil || vm.isWorking,
                    saveOptions: vm.saveOptions,
                    resetOptions: vm.resetOptions,
                    generateDump: vm.generateDump,
                    rootFolder: vm.rootFolder
                )
                UndumpSectionView(
                    dryRun: $vm.dryRun,
                    makeBackups: $vm.makeBackups,
                    autoLoadDump: $vm.autoLoadDump,
                    autoApply: $vm.autoApply,
                    selectedDumpPath: vm.selectedDumpURL?.path ?? "No path selected",
                    hasSelectedDump: vm.selectedDumpURL != nil,
                    loadFromSelected: vm.loadDumpFromSelectedPath,
                    pickDumpFile: vm.pickDumpFileForLoading,
                    clearSelectedDump: vm.clearSelectedDumpFile,
                    loadDumpFromFile: vm.loadDumpFromFile,
                    applyDumpToFolder: vm.applyDumpToFolder,
                    isApplyDisabled: vm.rootFolder == nil || vm.dumpText.isEmpty || vm.isWorking,
                    undumpReport: vm.undumpReport
                )
                ChatPromptSectionView(
                    onCopy: { copy(prompt) }
                )
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.windowBackground)
            .headerProminence(.standard)
            .navigationTitle("DumpUndump")
            .frame(minWidth: 220)
        } detail: {
            DumpDetailView(
                dumpText: $vm.dumpText,
                isWorking: vm.isWorking,
                lines: dumpLines,
                sizeString: dumpSizeString,
                tokens: dumpTokens,
                onCopy: vm.copyDumpToClipboard,
                onCopyFile: vm.copyDumpAsFileToPasteboard,
                onSave: vm.saveDumpToFile,
                onClear: {
                    vm.dumpReport = ""
                    vm.undumpReport = ""
                    vm.dumpText = ""
                }
            )
            .frame(minWidth: 120)
        }
        .frame(minHeight: 100)
        .tint(Theme.accent)
        .controlSize(.small)
        .alert(item: $vm.errorAlert) { err in
            Alert(title: Text("Error"), message: Text(err.message), dismissButton: .default(Text("OK")))
        }
        .task {
            updateDumpMetrics(vm.dumpText)
        }
        .onChange(of: vm.dumpText) { _, newValue in
            updateDumpMetrics(newValue)
        }
        .onChange(of: vm.options) { _, _ in
            optionsSaveWork?.cancel()
            let work = DispatchWorkItem { vm.saveOptions() }
            optionsSaveWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        }
    }

    private func updateDumpMetrics(_ text: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tokens = TokenCounter.estimateTokens(in: text)
            let bytes = text.utf8.count
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
            let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            DispatchQueue.main.async {
                dumpTokens = tokens
                dumpBytes = bytes
                dumpLines = lines
                dumpSizeString = size
            }
        }
    }

    private func copy(_ s: String) {
        guard !s.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
}
