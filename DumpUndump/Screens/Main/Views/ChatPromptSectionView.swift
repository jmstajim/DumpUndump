import SwiftUI

struct ChatPromptSectionView: View {
    @AppStorage("DumpUndump.Section.Prompt.isExpanded.v1") private var isExpanded: Bool = true
    @AppStorage("DumpUndump.ChatPrompt.v1") private var prompt: String = ""
    
    let onCopy: (() -> Void)

    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $prompt)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(minHeight: 96)
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
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
            .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
        } header: {
            HStack(spacing: 8) {
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
