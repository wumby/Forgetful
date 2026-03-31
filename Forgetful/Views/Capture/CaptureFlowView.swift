import SwiftData
import SwiftUI
import UIKit

struct CapturedImageSession: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = resolvedSourceType
        if resolvedSourceType == .camera {
            controller.cameraCaptureMode = .photo
        }
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    private var resolvedSourceType: UIImagePickerController.SourceType {
        #if targetEnvironment(simulator)
        #if DEBUG
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            return .photoLibrary
        }
        #endif
        return .savedPhotosAlbum
        #else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            return .camera
        }

        #if DEBUG
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            return .photoLibrary
        }
        #endif

        return .savedPhotosAlbum
        #endif
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }
    }
}

struct CaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]

    let image: UIImage
    let preselectedFolderID: UUID?
    let onSaveSuccess: ((String) -> Void)?

    @State private var note = ""
    @State private var selectedPreset = ExpirationPreset.sevenDays
    @State private var selectedFolderID: UUID?
    @State private var isPresentingFolderPicker = false
    @State private var isPresentingCreateFolder = false
    @State private var saveError: String?

    private let expirationService = ExpirationService()
    private let isUsingTestingFallback = !UIImagePickerController.isSourceTypeAvailable(.camera)

    init(image: UIImage, preselectedFolderID: UUID? = nil, onSaveSuccess: ((String) -> Void)? = nil) {
        self.image = image
        self.preselectedFolderID = preselectedFolderID
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isUsingTestingFallback {
                    fallbackNotice
                }

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )

                NoteInputCard(note: $note)
                ExpirationPresetPicker(selectedPreset: $selectedPreset)
                folderSection

                if let saveError {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveMemory()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $isPresentingFolderPicker) {
            NavigationStack {
                SaveFolderPickerSheet(
                    folders: folders,
                    selectedFolderID: $selectedFolderID,
                    isPresentingCreateFolder: $isPresentingCreateFolder
                )
            }
        }
        .sheet(isPresented: $isPresentingCreateFolder) {
            FolderEditorSheet(title: "New Folder", submitTitle: "Create") { name, color, icon in
                do {
                    try FolderService(context: modelContext).createFolder(name: name, colorName: color, iconName: icon)
                } catch {
                    saveError = "Could not create this folder. Try again."
                }
            }
        }
        .onAppear {
            selectedPreset = .sevenDays
            if selectedFolderID == nil {
                selectedFolderID = preselectedFolderID
            }
        }
    }

    @ViewBuilder
    private var fallbackNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Testing Mode")
                .font(.headline)

            Text("Camera hardware is unavailable here, so Forgetful is using a temporary debug fallback to let you test the save flow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private func saveMemory() {
        let service = MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)

        do {
            try service.createCaptureItem(image: image, note: note, folderId: selectedFolderID, expirationPreset: selectedPreset)
            onSaveSuccess?("Mementos")
            dismiss()
        } catch {
            saveError = "Could not save this memory. Try again."
        }
    }

    private var selectedFolder: FolderEntity? {
        folders.first(where: { $0.id == selectedFolderID })
    }

    private var folderTitle: String {
        selectedFolder?.name ?? "No Folder"
    }

    private var folderSymbol: String {
        selectedFolder?.iconName ?? "tray"
    }

    private var folderTint: Color {
        selectedFolder.map { Color(folderColorName: $0.colorName) } ?? .secondary
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folder")
                .font(.subheadline.weight(.semibold))

            Button {
                isPresentingFolderPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: folderSymbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(folderTint)
                        .frame(width: 34, height: 34)
                        .background(folderTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(folderTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SaveFolderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let folders: [FolderEntity]
    @Binding var selectedFolderID: UUID?
    @Binding var isPresentingCreateFolder: Bool

    var body: some View {
        List {
            Section {
                FolderPickerRow(
                    title: "No Folder",
                    subtitle: nil,
                    symbol: "tray",
                    tint: .secondary,
                    isSelected: selectedFolderID == nil
                ) {
                    selectedFolderID = nil
                    dismiss()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(folders, id: \.id) { folder in
                    FolderPickerRow(
                        title: folder.name,
                        subtitle: nil,
                        symbol: folder.iconName ?? "folder",
                        tint: Color(folderColorName: folder.colorName),
                        isSelected: selectedFolderID == folder.id
                    ) {
                        selectedFolderID = folder.id
                        dismiss()
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                if !folders.isEmpty {
                    Text("Folders")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Choose Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                    DispatchQueue.main.async {
                        isPresentingCreateFolder = true
                    }
                } label: {
                    Label("Create New Folder", systemImage: "plus")
                }
            }
        }
    }
}
