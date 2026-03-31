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

                    Button(role: .destructive) {
                        deleteFolder = folder
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
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

    @State private var isShowingCamera = false
    @State private var captureSession: CapturedImageSession?

    private let expirationService = ExpirationService()

    private var items: [MemoryItem] {
        let service = MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)
        return service.fetchActiveItems().filter { $0.folderId == folder?.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if items.isEmpty {
                    compactEmptyState
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(itemCountText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    MemoryCardGrid(
                        items: items,
                        assetStore: appManager.assetStore,
                        expirationService: expirationService
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(folder?.name ?? "No Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCamera = true
                } label: {
                    Image(systemName: "camera")
                }
                .accessibilityLabel("Capture into this folder")
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                captureSession = CapturedImageSession(image: image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $captureSession) { session in
            NavigationStack {
                CaptureFlowView(image: session.image, preselectedFolderID: folder?.id)
            }
        }
    }

    private var itemCountText: String {
        items.count == 1 ? "1 memento" : "\(items.count) mementos"
    }

    private var compactEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: folder?.iconName ?? "tray")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(folderColorName: folder?.colorName))
                .frame(width: 52, height: 52)
                .background(Color(folderColorName: folder?.colorName).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            Text("Nothing here yet")
                .font(.headline)

            Text("Use the camera button to add a memento directly to \(folder?.name ?? "No Folder").")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }
}

struct FolderEditorSheet: View {
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
    private let icons = [
        "folder",
        "tag",
        "bookmark",
        "tray",
        "house",
        "car",
        "cart",
        "doc.text",
        "bag",
        "fork.knife",
        "gift",
        "camera",
        "bell",
        "clock",
        "mappin.and.ellipse",
        "briefcase"
    ]

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.headline)
                                        .foregroundStyle(selectedIcon == icon ? .primary : .secondary)
                                        .frame(width: 46, height: 46)
                                        .background(
                                            selectedIcon == icon ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 14)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(selectedIcon == icon ? Color.primary.opacity(0.18) : Color.clear, lineWidth: 1.5)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
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
