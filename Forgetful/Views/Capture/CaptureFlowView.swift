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

    @State private var note = ""
    @State private var selectedPreset = ExpirationPreset.sevenDays
    @State private var selectedFolderID: UUID?
    @State private var saveError: String?

    private let expirationService = ExpirationService()
    private let isUsingTestingFallback = !UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Folder")
                        .font(.headline)

                    FolderPickerRow(
                        title: "Unsorted",
                        subtitle: "Leave this easy to find later",
                        symbol: "tray",
                        tint: .secondary,
                        isSelected: selectedFolderID == nil
                    ) {
                        selectedFolderID = nil
                    }

                    ForEach(folders, id: \.id) { folder in
                        FolderPickerRow(
                            title: folder.name,
                            subtitle: "Save into \(folder.name)",
                            symbol: folder.iconName ?? "folder",
                            tint: Color(folderColorName: folder.colorName),
                            isSelected: selectedFolderID == folder.id
                        ) {
                            selectedFolderID = folder.id
                        }
                    }
                }

                if let saveError {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Save Memory")
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
        .onAppear {
            let preferences = UserPreferences.fetchOrCreate(in: modelContext)
            selectedPreset = expirationService.preset(from: preferences.defaultExpirationPreset)
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
            dismiss()
        } catch {
            saveError = "Could not save this memory. Try again."
        }
    }
}
