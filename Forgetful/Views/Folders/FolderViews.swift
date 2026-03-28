import SwiftData
import SwiftUI

struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]

    @State private var isPresentingCreate = false
    @State private var renameFolder: FolderEntity?
    @State private var deleteFolder: FolderEntity?
    @State private var folderErrorMessage: String?

    private let expirationService = ExpirationService()

    var body: some View {
        List {
            ForEach(folders, id: \.id) { folder in
                NavigationLink {
                    FolderDetailView(folder: folder)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: folder.iconName ?? "folder")
                            .foregroundStyle(Color(folderColorName: folder.colorName))
                            .frame(width: 34)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(folder.name)
                                .font(.headline)
                            Text("\(FolderService(context: modelContext).activeItemCount(in: folder, expirationService: expirationService)) active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions {
                    Button("Rename") {
                        renameFolder = folder
                    }
                    .tint(.blue)

                    Button("Delete", role: .destructive) {
                        deleteFolder = folder
                    }
                }
            }
        }
        .navigationTitle("Folders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            FolderEditorSheet(title: "New Folder", submitTitle: "Create") { name, color, icon in
                do {
                    try FolderService(context: modelContext).createFolder(name: name, colorName: color, iconName: icon)
                } catch {
                    folderErrorMessage = error.localizedDescription
                }
            }
        }
        .sheet(item: $renameFolder) { folder in
            FolderEditorSheet(title: "Rename Folder", submitTitle: "Save", initialName: folder.name, initialColorName: folder.colorName, initialIconName: folder.iconName) { name, color, icon in
                do {
                    folder.colorName = color
                    folder.iconName = icon
                    try FolderService(context: modelContext).renameFolder(folder, name: name)
                } catch {
                    folderErrorMessage = error.localizedDescription
                }
            }
        }
        .alert("Delete Folder?", isPresented: Binding(get: {
            deleteFolder != nil
        }, set: { if !$0 { deleteFolder = nil } })) {
            Button("Move Items to Unsorted", role: .destructive) {
                if let deleteFolder {
                    do {
                        try FolderService(context: modelContext).deleteFolder(deleteFolder, moveItemsToUnsorted: true)
                    } catch {
                        folderErrorMessage = error.localizedDescription
                    }
                }
                self.deleteFolder = nil
            }
            Button("Cancel", role: .cancel) {
                deleteFolder = nil
            }
        } message: {
            Text("Items in this folder will be moved to Unsorted.")
        }
        .alert("Folder Error", isPresented: Binding(
            get: { folderErrorMessage != nil },
            set: { if !$0 { folderErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                folderErrorMessage = nil
            }
        } message: {
            Text(folderErrorMessage ?? "Something went wrong while updating folders.")
        }
    }
}

struct FolderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager

    let folder: FolderEntity?

    private let expirationService = ExpirationService()

    private var items: [MemoryItem] {
        let service = MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)
        return service.fetchActiveItems().filter { $0.folderId == folder?.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if items.isEmpty {
                    EmptyStateView(
                        title: "No items here",
                        message: folder == nil ? "Capture something and leave it unsorted, or move items here later." : "This folder is ready when you need it.",
                        symbol: "tray"
                    )
                } else {
                    MemoryCardGrid(
                        items: items,
                        assetStore: appManager.assetStore,
                        expirationService: expirationService,
                        folderNameProvider: { _ in folder?.name }
                    )
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(folder?.name ?? "Unsorted")
    }
}

private struct FolderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let submitTitle: String
    var initialName = ""
    var initialColorName: String? = "blue"
    var initialIconName: String? = "folder"
    let onSubmit: (String, String?, String?) -> Void

    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "folder"

    private let colors = ["blue", "green", "orange", "red", "pink", "teal"]
    private let icons = ["folder", "cart", "house", "car", "doc.text", "tag"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Folder name", text: $name)
                }

                Section("Color") {
                    HStack {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(folderColorName: color))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }

                Section("Icon") {
                    HStack {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(selectedIcon == icon ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(submitTitle) {
                        onSubmit(name.trimmingCharacters(in: .whitespacesAndNewlines), selectedColor, selectedIcon)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            name = initialName
            selectedColor = initialColorName ?? "blue"
            selectedIcon = initialIconName ?? "folder"
        }
    }
}
