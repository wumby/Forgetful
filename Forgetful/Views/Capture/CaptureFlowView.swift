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

    static var preferredSourceType: UIImagePickerController.SourceType? {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            return .camera
        }

        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            return .photoLibrary
        }

        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            return .savedPhotosAlbum
        }

        return nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        let sourceType = Self.preferredSourceType ?? .photoLibrary
        controller.sourceType = sourceType
        if sourceType == .camera {
            controller.cameraCaptureMode = .photo
        }
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

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

    @State private var note = ""
    @State private var selectedPreset = ExpirationPreset.sevenDays
    @State private var defaultPreset = ExpirationPreset.sevenDays
    @State private var shouldUpdateDefaultPreset = false
    @State private var selectedFolderID: UUID?
    @State private var isPresentingFolderPicker = false
    @State private var isPresentingCreateFolder = false
    @State private var isSaving = false
    @State private var saveError: String?

    private let expirationService = ExpirationService()
    private let isUsingFallbackSource = CameraCaptureView.preferredSourceType != .camera
    private let noteMaxLength = 140
    private let previewDate = Date.now

    init(image: UIImage, preselectedFolderID: UUID? = nil) {
        self.image = image
        self.preselectedFolderID = preselectedFolderID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isUsingFallbackSource {
                    fallbackNotice
                }

                CapturePolaroidComposer(
                    image: image,
                    note: $note,
                    createdAt: previewDate,
                    maxLength: noteMaxLength
                )
                ExpirationPresetPicker(selectedPreset: $selectedPreset)
                if selectedPreset != defaultPreset {
                    defaultPresetToggle
                }
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
        .scrollDismissesKeyboard(.interactively)
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
                .disabled(isSaving)
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
                    return true
                } catch {
                    saveError = error.localizedDescription
                    return false
                }
            }
        }
        .onAppear {
            let preferences = UserPreferences.fetchOrCreate(in: modelContext)
            let savedDefault = expirationService.preset(from: preferences.defaultExpirationPreset)
            defaultPreset = savedDefault
            selectedPreset = savedDefault
            shouldUpdateDefaultPreset = false
            if selectedFolderID == nil {
                selectedFolderID = preselectedFolderID
            }
        }
        .onChange(of: selectedPreset) { _, newValue in
            if newValue == defaultPreset {
                shouldUpdateDefaultPreset = false
            }
        }
        .onChange(of: note) { _, newValue in
            if newValue.count > noteMaxLength {
                note = String(newValue.prefix(noteMaxLength))
            }
        }
    }

    @ViewBuilder
    private var fallbackNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Testing Mode")
                .font(.headline)

            Text("Camera capture isn't available here, so Forgetful is using your photo library instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private func saveMemory() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let service = MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)
        let resolvedFolderID = folders.contains(where: { $0.id == selectedFolderID }) ? selectedFolderID : nil

        do {
            if shouldUpdateDefaultPreset {
                let preferences = UserPreferences.fetchOrCreate(in: modelContext)
                preferences.defaultExpirationPreset = selectedPreset.rawValue
                defaultPreset = selectedPreset
                try? modelContext.save()
            }
            try service.createCaptureItem(image: image, note: note, folderId: resolvedFolderID, expirationPreset: selectedPreset)
            dismiss()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription ?? "This memento couldn't be saved. Try again."
        }
    }

    private var defaultPresetToggle: some View {
        Button {
            shouldUpdateDefaultPreset.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: shouldUpdateDefaultPreset ? "checkmark.square.fill" : "square")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(shouldUpdateDefaultPreset ? .blue : .secondary)

                Text("Make \(selectedPreset.settingsTitle) the new default")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
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

private struct CapturePolaroidComposer: View {
    let image: UIImage
    @Binding var note: String
    let createdAt: Date
    let maxLength: Int

    private let photoHeight: CGFloat = 320
    private let footerMinHeightWithNote: CGFloat = 92
    private let footerMinHeightWithoutNote: CGFloat = 72
    private let outerCornerRadius: CGFloat = 12
    private let innerCornerRadius: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: photoHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius))

            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.custom("Noteworthy-Bold", size: 18))
                    .foregroundStyle(Color.black.opacity(0.76))
                    .tint(Color.black.opacity(0.72))
                    .scrollContentBackground(.hidden)
                    .lineLimit(1...3)
                    .overlay(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("Note here... (optional)")
                                .font(.custom("Noteworthy-Bold", size: 18))
                                .foregroundStyle(Color.black.opacity(0.34))
                                .allowsHitTesting(false)
                        }
                    }

                HStack(alignment: .center) {
                    Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.45))
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Spacer()

                    if !note.isEmpty {
                        Text("\(note.count)/\(maxLength)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(note.count >= maxLength ? .orange : Color.black.opacity(0.35))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: footerMinHeight, alignment: .topLeading)
            .padding(.top, note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 10 : 12)
            .padding(.bottom, 12)
            .padding(.horizontal, 14)
            .background(Color.white)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.94),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: outerCornerRadius)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }

    private var footerMinHeight: CGFloat {
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? footerMinHeightWithoutNote : footerMinHeightWithNote
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
                if folders.count < FolderService.maxFolderCount {
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
}
