import SwiftUI

struct HighlightingTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        let tv = NSTextView(frame: .zero)
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isEditable = true
        tv.isSelectable = true
        tv.usesFontPanel = false
        tv.usesFindPanel = true
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.textColor = .labelColor
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = true
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: .max, height: .max)
        tv.delegate = context.coordinator
        scroll.documentView = tv
        context.coordinator.textView = tv
        tv.string = text
        context.coordinator.rehighlight()
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != text {
            let selected = tv.selectedRanges
            tv.string = text
            context.coordinator.rehighlight()
            tv.selectedRanges = selected
        } else {
            context.coordinator.rehighlight()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: HighlightingTextView
        private let highlighter = SyntaxHighlighter()
        weak var textView: NSTextView?

        init(_ parent: HighlightingTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            rehighlight()
        }

        func rehighlight() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let baseFont = tv.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            highlighter.highlight(storage: storage, baseFont: baseFont)
            tv.typingAttributes = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ]
        }
    }
}
