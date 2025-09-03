import SwiftUI

struct DumpDetailView: View {
    @Binding var dumpText: String
    let isWorking: Bool
    let lines: Int
    let sizeString: String
    let onCopy: () -> Void
    let onCopyFile: () -> Void
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HighlightingTextView(text: $dumpText)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.bottom, 4)
        }
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .destructiveAction) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "clipboard")
                }
                .disabled(dumpText.isEmpty)
                Button(action: onCopyFile) {
                    Label(" Copy as File", systemImage: "doc.on.doc.fill")
                }
                .disabled(dumpText.isEmpty)
                Button(action: onSave) {
                    Label("Save to File…", systemImage: "square.and.arrow.down")
                }
                .disabled(dumpText.isEmpty)
                if isWorking {
                    ProgressView().controlSize(.small)
                }
            }
            ToolbarItemGroup(placement: .status) {
                Text("Dump contents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(lines) ln • \(sizeString)")
                    .font(.caption)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(role: .destructive, action: onClear) {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(dumpText.isEmpty)
                .buttonStyle(.bordered)
            }
        }
    }
}

