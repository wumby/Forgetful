import SwiftData
import SwiftUI

private enum LibraryMode: String, CaseIterable, Identifiable {
    case photos
    case folders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: "Mementos"
        case .folders: "Folders"
        }
    }
}

struct RootView: View {
    @State private var captureSession: CapturedImageSession?
    @State private var isShowingCamera = false
    @State private var captureErrorMessage: String?

    var body: some View {
        NavigationStack {
            LibraryView {
                openCapture()
            }
        }
        .tint(.primary)
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                captureSession = CapturedImageSession(image: image)
            }
            .ignoresSafeArea()
        }
        .alert("Capture Unavailable", isPresented: Binding(
            get: { captureErrorMessage != nil },
            set: { if !$0 { captureErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                captureErrorMessage = nil
            }
        } message: {
            Text(captureErrorMessage ?? "")
        }
        .sheet(item: $captureSession, onDismiss: handleCaptureFlowDismiss) { session in
            NavigationStack {
                CaptureFlowView(image: session.image)
            }
        }
    }

    private func openCapture() {
        guard CameraCaptureView.preferredSourceType != nil else {
            captureErrorMessage = "Camera capture isn't available, and this device can't open the photo library right now."
            return
        }

        isShowingCamera = true
    }

    private func handleCaptureFlowDismiss() {
        captureSession = nil
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]
    @State private var selectedMode: LibraryMode = .photos
    @State private var selectedSort: MemorySort = .newestFirst
    @State private var isPresentingCreateFolder = false
    @State private var folderErrorMessage: String?
    let onCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MementosHeader(
                selectedMode: $selectedMode,
                onCapture: onCapture,
                onAddFolder: presentCreateFolder
            )

            TabView(selection: $selectedMode) {
                LibraryPhotosView(selectedSort: $selectedSort)
                    .tag(LibraryMode.photos)

                LibraryFoldersView()
                    .tag(LibraryMode.folders)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingCreateFolder) {
            FolderEditorSheet(title: "New Folder", submitTitle: "Create") { name, color, icon in
                do {
                    try FolderService(context: modelContext).createFolder(name: name, colorName: color, iconName: icon)
                    return true
                } catch {
                    folderErrorMessage = error.localizedDescription
                    return false
                }
            }
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

    private func presentCreateFolder() {
        guard folders.count < FolderService.maxFolderCount else {
            folderErrorMessage = FolderServiceError.folderLimitReached.localizedDescription
            return
        }
        isPresentingCreateFolder = true
    }
}

private struct MementosHeader: View {
    @Binding var selectedMode: LibraryMode
    let onCapture: () -> Void
    let onAddFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Forgetful")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }

                Spacer(minLength: 12)

                Button(action: selectedMode == .folders ? onAddFolder : onCapture) {
                    Image(systemName: selectedMode == .folders ? "plus" : "camera")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedMode == .folders ? "Add folder" : "Capture memory")
            }

            LibraryModeSwitcher(selectedMode: $selectedMode)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

private struct LibraryModeSwitcher: View {
    @Binding var selectedMode: LibraryMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibraryMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 7) {
                        Text(mode.title)
                            .font(.system(size: 16, weight: selectedMode == mode ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(selectedMode == mode ? .primary : .secondary)
                            .frame(maxWidth: .infinity)

                        Capsule()
                            .fill(selectedMode == mode ? Color.white.opacity(0.9) : Color.clear)
                            .frame(width: 28, height: 3)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

private struct LibraryPhotosView: View {
    @Binding var selectedSort: MemorySort

    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var allStoredItems: [MemoryItem]

    private let expirationService = ExpirationService()

    private func sortButton(_ sort: MemorySort) -> some View {
        Button {
            selectedSort = sort
        } label: {
            if selectedSort == sort {
                Label(sort.title, systemImage: "checkmark")
            } else {
                Text(sort.title)
            }
        }
    }

    var body: some View {
        let allItems = allStoredItems.filter { expirationService.isActive($0) }
        let displayedItems = allItems.sortedMementos(using: selectedSort)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Text(allItems.count == 1 ? "1 memento" : "\(allItems.count) mementos")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Section("Sort") {
                            sortButton(.newestFirst)
                            sortButton(.oldestFirst)
                            sortButton(.expiringSoonest)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sortLabel)
                                .font(.footnote.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if displayedItems.isEmpty {
                    CompactEmptyStateView(
                        title: "No memories yet",
                        message: "Your temporary captures will appear here.",
                        symbol: "photo.on.rectangle"
                    )
                } else {
                    MemoryCardGrid(
                        items: displayedItems,
                        assetStore: appManager.assetStore,
                        expirationService: expirationService
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 42)
        }
    }

    private var sortLabel: String {
        selectedSort.shortTitle
    }
}

private struct LibraryFoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var allItems: [MemoryItem]

    @State private var renameFolder: FolderEntity?
    @State private var deleteFolder: FolderEntity?
    @State private var folderErrorMessage: String?
    private let expirationService = ExpirationService()

    private var itemCountsByFolder: [UUID: Int] {
        allItems.reduce(into: [:]) { counts, item in
            guard expirationService.isActive(item), let folderId = item.folderId else { return }
            counts[folderId, default: 0] += 1
        }
    }

    var body: some View {
        List {
            if folders.isEmpty {
                CompactEmptyStateView(
                    title: "No folders yet",
                    message: "Create a folder to keep related memories together.",
                    symbol: "folder"
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 28, leading: 20, bottom: 28, trailing: 20))
                .listRowBackground(Color.clear)
            } else {
                ForEach(folders, id: \.id) { folder in
                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                renameFolder = folder
                            } label: {
                                Label("Edit Folder", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                deleteFolder = folder
                            } label: {
                                HStack {
                                    Text("Delete Folder")
                                    Spacer()
                                    Image(uiImage: tintedTrashIcon)
                                }
                                .foregroundStyle(.red)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.04), in: Circle())
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            FolderDetailView(folder: folder)
                        } label: {
                            FolderRowCell(
                                folder: folder,
                                count: itemCountsByFolder[folder.id, default: 0]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .sheet(item: $renameFolder) { folder in
            FolderEditorSheet(
                title: "Rename Folder",
                submitTitle: "Save",
                initialName: folder.name,
                initialColorName: folder.colorName,
                initialIconName: folder.iconName
            ) { name, color, icon in
                let originalColor = folder.colorName
                let originalIcon = folder.iconName
                do {
                    folder.colorName = color
                    folder.iconName = icon
                    try FolderService(context: modelContext).renameFolder(folder, name: name)
                    return true
                } catch {
                    folder.colorName = originalColor
                    folder.iconName = originalIcon
                    folderErrorMessage = error.localizedDescription
                    return false
                }
            }
        }
        .alert("Delete Folder?", isPresented: Binding(get: {
            deleteFolder != nil
        }, set: { if !$0 { deleteFolder = nil } })) {
            Button("Move Items to No Folder", role: .destructive) {
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
            Text("Memories in this folder will stay in Forgetful and be moved to No Folder.")
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

private struct FolderRowCell: View {
    let folder: FolderEntity
    let count: Int

    private var tint: Color { Color(folderColorName: folder.colorName) }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: folder.iconName ?? "folder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(count == 1 ? "1 memento" : "\(count) mementos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private var tintedTrashIcon: UIImage {
    let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
    return UIImage(systemName: "trash", withConfiguration: configuration)?
        .withTintColor(.systemRed, renderingMode: .alwaysOriginal) ?? UIImage()
}
