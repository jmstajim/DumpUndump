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
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Dry run (no writes)", isOn: $dryRun)
                Toggle("Create *.bak backups", isOn: $makeBackups)
                Toggle("Auto-reload dump when file changes", isOn: $autoLoadDump)
                Toggle("Auto-apply dump after loading", isOn: $autoApply)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dump file path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "document")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                        Text(selectedDumpPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button(action: pickDumpFile) {
                            Text("Choose…")
                        }
                        .buttonStyle(.bordered)
                    }
                    HStack(spacing: 6) {
                        Button(action: loadDumpFromFile) {
                            Label {
                                Text("Load file")
                            } icon: {
                                Image(systemName: "doc.fill.badge.plus")
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Theme.accent)
                            }
                            .frame(maxWidth: .infinity, minHeight: 22)
                        }
                        .buttonStyle(.bordered)
                        Button(action: loadFromSelected) {
                            Label {
                                Text("Load from path")
                            } icon: {
                                Image(systemName: "arrow.down.document.fill")
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Theme.accent)
                            }
                            .frame(maxWidth: .infinity, minHeight: 22)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasSelectedDump)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: applyDumpToFolder) {
                            Label {
                                Text("Undump")
                            } icon: {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Theme.accent)
                            }
                            .frame(maxWidth: .infinity, minHeight: 22)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isApplyDisabled)
                    }
                    .padding(.top, 2)
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
            .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
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
