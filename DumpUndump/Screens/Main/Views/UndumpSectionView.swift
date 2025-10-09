import SwiftUI

struct UndumpSectionView: View {
    @AppStorage("DumpUndump.Section.Undump.isExpanded.v1") private var isExpanded: Bool = true
    @Binding var dryRun: Bool
    @Binding var makeBackups: Bool
    @Binding var autoLoadDump: Bool
    @Binding var autoApply: Bool
    let selectedDumpPath: String
    let hasSelectedDump: Bool
    let loadFromSelected: () -> Void
    let pickDumpFile: () -> Void
    let clearSelectedDump: () -> Void
    let loadDumpFromFile: () -> Void
    let applyDumpToFolder: () -> Void
    let isApplyDisabled: Bool
    let undumpReport: String

    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Dry run (no writes)", isOn: $dryRun)
                Toggle("Create *.bak backups", isOn: $makeBackups)
                Toggle("Auto‑reload dump when file changes", isOn: $autoLoadDump)
                Toggle("Auto‑apply dump after loading", isOn: $autoApply)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dump file path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "document")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                        Text(selectedDumpPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(action: pickDumpFile) {
                            Text("Choose…")
                        }
                        .buttonStyle(.bordered)
                        if hasSelectedDump {
                            Button(role: .destructive, action: clearSelectedDump) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Button(action: loadDumpFromFile) {
                            Label("Load file", systemImage: "doc.fill.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 24)
                            
                        }
                        Button(action: loadFromSelected) {
                            Label("Load from path", systemImage: "arrow.down.document.fill")
                                .frame(maxWidth: .infinity, minHeight: 24)

                        }
                        .disabled(!hasSelectedDump)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: applyDumpToFolder) {
                                Label("Undump", systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isApplyDisabled)
                    }
                    .padding(.top, 4)
                }
                if undumpReport.isEmpty {
                    Text("")
                        .font(.footnote)
                } else {
                    Text(undumpReport)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formCard()
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        } header: {
            Label("Undump and apply", systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                .font(.headline)
        }
    }
}

#Preview {
    @Previewable @State var dryRun = false
    @Previewable @State var makeBackups = false
    @Previewable @State var autoLoadDump = true
    @Previewable @State var autoApply = true
    UndumpSectionView(dryRun: $dryRun, makeBackups: $makeBackups, autoLoadDump: $autoLoadDump, autoApply: $autoApply, selectedDumpPath: "/Users/me/file.txt", hasSelectedDump: true, loadFromSelected: {}, pickDumpFile: {}, clearSelectedDump: {}, loadDumpFromFile: {}, applyDumpToFolder: {}, isApplyDisabled: false, undumpReport: "")
}
