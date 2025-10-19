import SwiftUI

struct DumpDetailView: View {
    @Binding var dumpText: String
    let isWorking: Bool
    let lines: Int
    let sizeString: String
    let tokens: Int
    let onCopy: () -> Void
    let onCopyFile: () -> Void
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HighlightingTextView(text: $dumpText)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "clipboard")
                }
                .labelStyle(.iconOnly)
                .disabled(dumpText.isEmpty)

                Button(action: onCopyFile) {
                    Label("Copy as File", systemImage: "doc.on.doc.fill")
                }
                .labelStyle(.iconOnly)
                .disabled(dumpText.isEmpty)

                Button(action: onSave) {
                    Label("Save to File…", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.iconOnly)
                .disabled(dumpText.isEmpty)

                if isWorking {
                    Button(action: {}) {
                        ProgressView().controlSize(.small)
                    }
                    .labelStyle(.iconOnly)
                }
            }
            ToolbarItemGroup(placement: .status) {
                Text("≈ \(tokens) tok · \(lines) ln · \(sizeString)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(role: .destructive, action: onClear) {
                    Label("Clear", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .disabled(dumpText.isEmpty)
            }
        }
    }
}
