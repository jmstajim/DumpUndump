import SwiftUI

struct RootFolderSectionView: View {
    @AppStorage("DumpUndump.Section.RootFolder.isExpanded.v1") private var isExpanded: Bool = true
    let path: String
    let onPick: () -> Void

    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "folder")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(path)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button(action: onPick) {
                            Text("Choose folder…")
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer(minLength: 0)
                }
            }
            .formCard()
            .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
        } header: {
            Label("Project Folder", systemImage: "folder.fill.badge.gearshape")
                .font(.headline)
        }
    }
}

#Preview {
    RootFolderSectionView(path: "", onPick: {})
}
