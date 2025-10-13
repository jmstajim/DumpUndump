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
        VStack(spacing: 8) {
            HighlightingTextView(text: $dumpText)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
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
                Text("Dump contents   ≈ \(tokens) Tok  •  \(lines) Ln  •  \(sizeString)")
                    .font(.caption)
                    .padding(.horizontal, 16)
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
