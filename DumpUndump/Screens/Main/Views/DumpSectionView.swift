import SwiftUI

struct DumpSectionView: View {
    @AppStorage("DumpUndump.Section.Dump.isExpanded.v1") private var isExpanded: Bool = true
    @Binding var selectedPreset: OptionsPreset
    @Binding var options: DumpOptions
    let isWorking: Bool
    let dumpReport: String
    let isGenerateDisabled: Bool
    let applyPreset: () -> Void
    let saveOptions: () -> Void
    let resetOptions: () -> Void
    let generateDump: () -> Void

    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Preset", selection: $selectedPreset) {
                        ForEach(OptionsPreset.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    Button(action: applyPreset) {
                        Image(systemName: "return.left")
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive, action: resetOptions) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                }
                HStack {
                    Toggle(" ", isOn: $options.skipLargeFiles)
                    Stepper(value: $options.maxSizeMB, in: 1...50) {
                        Text("Skip large files (> \(options.maxSizeMB) MB)")
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Include files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(DumpOptions.default.includeGlobs, text: $options.includeGlobs)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exclude files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(DumpOptions.default.excludeGlobs, text: $options.excludeGlobs)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exclude folders")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(DumpOptions.default.excludeDirs, text: $options.excludeDirs)
                        .textFieldStyle(.roundedBorder)
                }
                Button(action: generateDump) {
                    HStack {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        }
                        Label("Dump", systemImage: "shippingbox.fill")
                    }
                    .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerateDisabled)
                if dumpReport.isEmpty {
                    Text("")
                        .font(.footnote)
                } else {
                    Text(dumpReport)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formCard()
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        } header: {
            Label("Dump into a single text", systemImage: "shippingbox.fill")
                .font(.headline)
        }
    }
}

#Preview {
    @Previewable @State var selectedPreset = OptionsPreset.default
    @Previewable @State var options = DumpOptions.init(includeGlobs: "", excludeGlobs: "", excludeDirs: "", skipLargeFiles: false, maxSizeMB: 5)

    DumpSectionView(selectedPreset: $selectedPreset, options: $options, isWorking: false, dumpReport: "", isGenerateDisabled: true, applyPreset: {}, saveOptions: {}, resetOptions: {}, generateDump: {})
}

