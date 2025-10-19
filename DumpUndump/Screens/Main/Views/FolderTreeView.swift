import SwiftUI

struct FSNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDir: Bool
    var children: [FSNode]? = nil
}

private func buildNodes(at url: URL, base: String) -> [FSNode] {
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    var out: [FSNode] = []
    for child in items {
        if (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { continue }
        let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let rel: String
        if child.path.hasPrefix(base) {
            rel = String(child.path.dropFirst(base.count))
        } else {
            rel = child.lastPathComponent
        }

        if isDir {
            let kids = buildNodes(at: child, base: base).sortedByFolderThenName()
            out.append(FSNode(name: child.lastPathComponent, path: rel, isDir: true, children: kids.isEmpty ? nil : kids))
        } else {
            out.append(FSNode(name: child.lastPathComponent, path: rel, isDir: false, children: nil))
        }
    }
    return out.sortedByFolderThenName()
}

struct FolderTreeView: View {
    let rootURL: URL?
    @Binding var selection: Set<String>

    @State private var nodes: [FSNode] = []
    @State private var pathIndex: [String: FSNode] = [:]
    @State private var expanded: Set<String> = [""]

    private var layoutKey: String {
        let expandedKey = expanded.sorted().joined(separator: "|")
        return expandedKey + "#" + String(visibleCount())
    }

    var body: some View {
        let key = layoutKey
        return Group {
            if let _ = rootURL {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(visibleNodes(), id: \.node.id) { item in
                        NodeRow(
                            level: item.level,
                            node: item.node,
                            hasChildren: (item.node.children?.isEmpty == false),
                            isExpanded: expanded.contains(item.node.path),
                            state: state(for: item.node),
                            onToggleCheck: { toggle(node: item.node) },
                            onDisclosureTap: { recursive in
                                guard item.node.isDir, (item.node.children?.isEmpty == false) else { return }
                                toggleExpand(path: item.node.path, recursive: recursive)
                            },
                            onRowTap: {
                                guard item.node.isDir, (item.node.children?.isEmpty == false) else { return }
                                toggleExpand(path: item.node.path, recursive: false)
                            }
                        )
                    }
                }
                .padding(.vertical, 1)
                .padding(.leading, 1)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Select a project folder to choose files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .id(key)
        .animation(.default, value: key)
        .task(id: rootURL?.path) {
            await buildTree()
        }
    }

    @MainActor
    private func buildTree() async {
        guard let root = rootURL else {
            nodes = []
            pathIndex = [:]
            expanded = [""]
            return
        }
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let children: [FSNode] = {
            let needs = root.startAccessingSecurityScopedResource()
            defer { if needs { root.stopAccessingSecurityScopedResource() } }
            return buildNodes(at: root, base: base)
        }()

        let kids = children.sortedByFolderThenName()
        let project = FSNode(name: root.lastPathComponent, path: "", isDir: true, children: kids.isEmpty ? nil : kids)
        nodes = [project]

        var idx: [String: FSNode] = [:]
        func indexify(_ n: FSNode) {
            idx[n.path] = n
            if let cs = n.children { for c in cs { indexify(c) } }
        }
        indexify(project)
        pathIndex = idx
        expanded = [""]
        cleanupDanglingExclusions()
    }

    private func toggleExpand(path: String, recursive: Bool) {
        if expanded.contains(path) {
            collapseSubtree(startingAt: path)
        } else {
            if recursive {
                expandSubtree(startingAt: path)
            } else {
                expanded.insert(path)
            }
        }
    }

    private func collapseSubtree(startingAt path: String) {
        guard let node = pathIndex[path] else {
            expanded.remove(path)
            return
        }
        for p in allDirPathsUnder(node, includeSelf: true) {
            expanded.remove(p)
        }
    }

    private func expandSubtree(startingAt path: String) {
        guard let node = pathIndex[path] else {
            expanded.insert(path)
            return
        }
        for p in allDirPathsUnder(node, includeSelf: true) {
            expanded.insert(p)
        }
    }

    private func allDirPathsUnder(_ node: FSNode, includeSelf: Bool) -> [String] {
        var acc: [String] = []
        func walk(_ n: FSNode) {
            if n.isDir, (n.children?.isEmpty == false) {
                acc.append(n.path)
                for c in n.children ?? [] { walk(c) }
            }
        }
        if includeSelf { walk(node) } else {
            for c in node.children ?? [] { walk(c) }
        }
        return acc
    }

    private struct VisibleItem {
        let node: FSNode
        let level: Int
    }

    private func visibleNodes() -> [VisibleItem] {
        guard let root = nodes.first else { return [] }
        var out: [VisibleItem] = []
        func walk(_ n: FSNode, level: Int) {
            out.append(VisibleItem(node: n, level: level))
            if n.isDir, expanded.contains(n.path), let cs = n.children {
                for c in cs { walk(c, level: level + 1) }
            }
        }
        walk(root, level: 0)
        return out
    }

    private func visibleCount() -> Int {
        guard let root = nodes.first else { return 0 }
        var count = 0
        func walk(_ n: FSNode) {
            count += 1
            if n.isDir, expanded.contains(n.path), let cs = n.children {
                for c in cs { walk(c) }
            }
        }
        walk(root)
        return count
    }

    enum CheckState { case on, off, mixed }

    private func state(for node: FSNode) -> CheckState {
        if node.isDir && node.path.isEmpty {
            if allImmediateChildrenSelected(of: node) { return .on }
            return hasAnyEffectivelySelectedDescendant(node) ? .mixed : .off
        }

        if node.isDir {
            if node.children == nil {
                return isEffectivelySelectedDir(node.path) ? .on : .off
            }

            if allImmediateChildrenSelected(of: node) && !hasExclusions(under: node.path) {
                return .on
            }
            if hasAnyEffectivelySelectedDescendant(node) || (selection.contains(node.path) && hasExclusions(under: node.path)) {
                return .mixed
            } else {
                return .off
            }
        } else {
            return isEffectivelySelectedPath(node.path) ? .on : .off
        }
    }

    private func isExcluded(_ path: String) -> Bool {
        if selection.contains("!" + path) { return true }
        var comps = path.split(separator: "/")
        while !comps.isEmpty {
            comps.removeLast()
            let anc = comps.joined(separator: "/")
            if anc.isEmpty { break }
            if selection.contains("!" + anc) { return true }
        }
        return false
    }

    private func isEffectivelySelectedDir(_ path: String) -> Bool {
        if path.isEmpty { return false }
        if isExcluded(path) { return false }
        if selection.contains(path) { return true }

        var comps = path.split(separator: "/")
        while !comps.isEmpty {
            comps.removeLast()
            let anc = comps.joined(separator: "/")
            if anc.isEmpty { break }
            if selection.contains("!" + anc) { return false }
            if selection.contains(anc) { return true }
        }
        return false
    }

    private func isEffectivelySelectedPath(_ path: String) -> Bool {
        if isExcluded(path) { return false }
        if selection.contains(path) { return true }
        var comps = path.split(separator: "/")
        while !comps.isEmpty {
            comps.removeLast()
            let anc = comps.joined(separator: "/")
            if anc.isEmpty { break }
            if selection.contains("!" + anc) { return false }
            if selection.contains(anc) { return true }
        }
        return false
    }

    private func hasAnyEffectivelySelectedDescendant(_ node: FSNode) -> Bool {
        guard let kids = node.children else { return false }
        for k in kids {
            if k.isDir {
                if isEffectivelySelectedDir(k.path) { return true }
                if hasAnyEffectivelySelectedDescendant(k) { return true }
            } else {
                if isEffectivelySelectedPath(k.path) { return true }
            }
        }
        return false
    }

    private func allImmediateChildrenSelected(of node: FSNode) -> Bool {
        guard let kids = node.children else { return true }
        for k in kids {
            if k.isDir {
                if !isEffectivelySelectedDir(k.path) { return false }
            } else {
                if !isEffectivelySelectedPath(k.path) { return false }
            }
        }
        return true
    }

    private func allDescendantFilesSelected(for node: FSNode) -> Bool {
        let files = descendantFiles(of: node)
        if files.isEmpty { return true }
        for f in files {
            if !isEffectivelySelectedPath(f) { return false }
        }
        return true
    }

    private func descendantFiles(of node: FSNode) -> [String] {
        var out: [String] = []
        if let kids = node.children {
            for k in kids {
                if k.isDir {
                    out += descendantFiles(of: k)
                } else {
                    out.append(k.path)
                }
            }
        }
        return out
    }

    private func toggle(node: FSNode) {
        if node.isDir {
            toggleFolder(node)
        } else {
            toggleFile(node)
        }
    }

    private func toggleFolder(_ node: FSNode) {
        if node.path.isEmpty {
            if allImmediateChildrenSelected(of: node) {
                selection.removeAll()
            } else if let kids = node.children {
                selection.removeAll()
                for k in kids { selection.insert(k.path) }
            }
            cleanupDanglingExclusions()
            return
        }

        let st = state(for: node)
        switch st {
        case .on:
            setFolder(node.path, selected: false)
        case .off, .mixed:
            setFolder(node.path, selected: true)
        }
    }

    private func setFolder(_ path: String, selected makeSelected: Bool) {
        if makeSelected {
            removeExplicitUnder(prefixPath: path)
            removeExclusionsUnder(prefixPath: path)
            selection.remove("!" + path)
            selection.insert(path)
            compressUpwards(fromPath: parentPath(of: path))
        } else {
            let hasAncestor = nearestSelectedAncestor(ofPath: path) != nil
            removeExplicitUnder(prefixPath: path)
            selection.remove(path)
            removeExclusionsUnder(prefixPath: path)
            if hasAncestor {
                selection.insert("!" + path)
            }
            cleanupDanglingExclusions()
        }
    }

    private func toggleFile(_ node: FSNode) {
        if isEffectivelySelectedPath(node.path) {
            if selection.contains(node.path) {
                selection.remove(node.path)
                if nearestSelectedAncestor(ofPath: node.path) != nil {
                    addExclusion(for: node.path)
                }
            } else if nearestSelectedAncestor(ofPath: node.path) != nil {
                addExclusion(for: node.path)
            } else {
                selection.remove(node.path)
            }
        } else {
            if !removeExclusion(for: node.path) {
                selection.insert(node.path)
            }
        }
        cleanupDanglingExclusions()
        compressUpwards(fromPath: parentPath(of: node.path))
    }

    private func addExclusion(for path: String) {
        selection.insert("!" + path)
    }

    @discardableResult
    private func removeExclusion(for path: String) -> Bool {
        let tag = "!" + path
        if selection.contains(tag) {
            selection.remove(tag)
            let pref = tag + "/"
            selection = selection.filter { !$0.hasPrefix(pref) }
            return true
        }
        return false
    }

    private func removeExclusionsUnder(prefixPath: String) {
        let tag = "!" + prefixPath
        let pref = (tag.hasSuffix("/")) ? tag : tag + "/"
        selection = selection.filter { $0 != tag && !$0.hasPrefix(pref) }
    }

    private func removeExplicitUnder(prefixPath: String) {
        let pref = prefixPath.hasSuffix("/") ? prefixPath : prefixPath + "/"
        selection = selection.filter { !$0.hasPrefix(pref) && !$0.hasPrefix("!" + pref) && $0 != prefixPath && $0 != "!" + prefixPath }
    }

    private func nearestSelectedAncestor(ofPath path: String) -> String? {
        var comps = path.split(separator: "/")
        while !comps.isEmpty {
            comps.removeLast()
            let anc = comps.joined(separator: "/")
            if anc.isEmpty { break }
            if selection.contains(anc) { return anc }
        }
        return nil
    }

    private func parentPath(of path: String) -> String? {
        var comps = path.split(separator: "/")
        guard !comps.isEmpty else { return nil }
        comps.removeLast()
        if comps.isEmpty { return "" }
        return comps.joined(separator: "/")
    }

    private func compressUpwards(fromPath start: String?) {
        guard var current = start else { return }
        while true {
            guard let node = pathIndex[current] else { break }
            if allImmediateChildrenSelected(of: node) && !hasExclusions(under: current) {
                if !current.isEmpty {
                    let pref = current.hasSuffix("/") ? current : current + "/"
                    selection = selection.filter { !$0.hasPrefix(pref) && !$0.hasPrefix("!" + pref) }
                    selection.insert(current)
                }
                let next = parentPath(of: current) ?? ""
                if next == current { break }
                current = next
                if current == "" { break }
            } else {
                break
            }
        }
    }

    private func hasExclusions(under path: String) -> Bool {
        let tag = "!" + path
        if selection.contains(tag) { return true }
        let pref = tag + "/"
        return selection.contains(where: { $0.hasPrefix(pref) })
    }

    private func cleanupDanglingExclusions() {
        var toRemove: [String] = []
        for item in selection where item.hasPrefix("!") {
            let p = String(item.dropFirst())
            if nearestSelectedAncestor(ofPath: p) == nil {
                toRemove.append(item)
            }
        }
        for r in toRemove { selection.remove(r) }
    }

    struct NodeRow: View {
        let level: Int
        let node: FSNode
        let hasChildren: Bool
        let isExpanded: Bool
        let state: CheckState
        let onToggleCheck: () -> Void
        let onDisclosureTap: (_ recursive: Bool) -> Void
        let onRowTap: () -> Void

        var body: some View {
            HStack(spacing: 4) {
                Rectangle().fill(.clear).frame(width: CGFloat(level) * 6, height: 1)

                Group {
                    if node.isDir && hasChildren {
                        disclosure
                            .frame(width: 12)
                    } else {
                        Rectangle().fill(.clear).frame(width: 12, height: 1)
                    }
                }

                Button(action: onToggleCheck) {
                    Image(systemName: checkboxIcon)
                }
                .buttonStyle(.plain)

                Image(systemName: node.isDir ? "folder" : "doc.text")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)

                Text(node.name)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                if node.isDir && state == .mixed {
                    Image(systemName: "minus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onRowTap() }
            .padding(.vertical, 2)
        }

        @ViewBuilder private var disclosure: some View {
            let icon = Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .imageScale(.small)
            icon
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().modifiers(.option).onEnded {
                        onDisclosureTap(true)
                    }
                )
                .onTapGesture {
                    onDisclosureTap(false)
                }
        }

        private var checkboxIcon: String {
            switch state {
            case .on: return "checkmark.square"
            case .off: return "square"
            case .mixed: return "minus.square"
            }
        }
    }
}

extension Array where Element == FSNode {
    func sortedByFolderThenName() -> [FSNode] {
        self.sorted { a, b in
            if a.isDir != b.isDir { return a.isDir && !b.isDir }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
