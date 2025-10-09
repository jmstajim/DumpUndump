import AppKit

enum FolderPicker {
    static func pickFolder() -> URL? {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        p.canCreateDirectories = false
        p.resolvesAliases = true
        p.prompt = "Choose folder"
        return p.runModal() == .OK ? p.url : nil
    }
}

enum FilePanel {
    static func saveText(suggestedName: String) -> URL? {
        let p = NSSavePanel()
        p.canCreateDirectories = true
        p.allowedContentTypes = [.plainText]
        p.nameFieldStringValue = suggestedName
        return p.runModal() == .OK ? p.url : nil
    }
    static func openText() -> URL? {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.allowedContentTypes = [.plainText]
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        return p.runModal() == .OK ? p.url : nil
    }
}
