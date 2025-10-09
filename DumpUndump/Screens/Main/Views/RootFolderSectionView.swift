import SwiftUI

struct RootFolderSectionView: View {
    @AppStorage("DumpUndump.Section.RootFolder.isExpanded.v1") private var isExpanded: Bool = true
    let path: String
    let onPick: () -> Void

    var body: some View {
        Section(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: "folder")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(path)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button(action: onPick) {
                            Text("Choose folder…")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            }
            .formCard()
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        } header: {
            Label("Project Folder", systemImage: "folder.fill.badge.gearshape")
                .font(.headline)
        }
    }
}

#Preview {
    RootFolderSectionView(path: "", onPick: {})
}
