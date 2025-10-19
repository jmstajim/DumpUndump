import SwiftUI

struct DumpSectionView: View {
    @AppStorage("DumpUndump.Section.Dump.isExpanded.v1") private var isExpanded: Bool = true
    @Binding var options: DumpOptions
    let isWorking: Bool
    let dumpReport: String
    let isGenerateDisabled: Bool
    let saveOptions: () -> Void
    let resetOptions: () -> Void
    let generateDump: () -> Void
    let rootFolder: URL?
    
    @State private var selectionSet: Set<String> = []
    
    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Toggle("", isOn: $options.skipLargeFiles)
                        .labelsHidden()
                    Stepper(value: $options.maxSizeMB, in: 1...50) {
                        Text("Skip > \(options.maxSizeMB) MB")
                    }
                    Spacer(minLength: 0)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Folders & Files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    FolderTreeView(rootURL: rootFolder, selection: $selectionSet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Button(action: generateDump) {
                    HStack(spacing: 6) {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        }
                        Label("Dump", systemImage: "shippingbox.fill").labelStyle(.titleAndIcon)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.bordered)
                .disabled(isGenerateDisabled)
                
                if dumpReport.isEmpty {
                    Text("").font(.footnote)
                } else {
                    Text(dumpReport)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formCard()
            .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
            .task {
                selectionSet = Set(options.selectedPaths ?? [])
            }
            .onChange(of: options) { _, newValue in
                selectionSet = Set(newValue.selectedPaths ?? [])
            }
            .onChange(of: selectionSet) { _, newValue in
                let arr = Array(newValue).sorted()
                options.selectedPaths = arr.isEmpty ? nil : arr
                saveOptions()
            }
        } header: {
            Label("Dump into a single text", systemImage: "shippingbox.fill")
                .font(.headline)
        }
    }
}

#Preview {
    @Previewable @State var options = DumpOptions(skipLargeFiles: false, maxSizeMB: 5)
    DumpSectionView(options: $options, isWorking: false, dumpReport: "", isGenerateDisabled: true, saveOptions: {}, resetOptions: {}, generateDump: {}, rootFolder: nil)
}
