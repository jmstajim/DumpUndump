import SwiftUI

struct ChatPromptSectionView: View {
    @AppStorage("DumpUndump.Section.Prompt.isExpanded.v1") private var isExpanded: Bool = true
    @AppStorage("DumpUndump.ChatPrompt.v1") private var prompt: String = ""
    
    let onCopy: (() -> Void)

    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $prompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .scrollDisabled(true)
            }
            .formCard()
            .task {
                if prompt.isEmpty {
                    if let url = Bundle.main.url(forResource: "prompt_en", withExtension: "txt"),
                       let s = try? String(contentsOf: url, encoding: .utf8) {
                        prompt = s
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 12, trailing: 8))
        } header: {
            HStack {
                Label("AI Prompt", systemImage: "text.badge.star")
                    .font(.headline)
                Button("Copy", systemImage: "clipboard", action: onCopy)
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    ChatPromptSectionView(onCopy: {})
}

