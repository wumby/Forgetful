import SwiftData
import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]

    let item: MemoryItem

    @State private var exportMessage: String?
    @State private var isExporting = false
    @State private var isShowingFolderPicker = false
    @State private var isShowingDeleteConfirmation = false

    private let expirationService = ExpirationService()
    private let photosExportService = PhotosExportService()

    var body: some View {
        let memoryService = MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MemoryHeroImage(image: appManager.assetStore.loadOriginal(filename: item.imageFilename))

                MemoryMetaCard(
                    item: item,
                    countdownText: expirationService.countdownText(for: item),
                    folderName: folderName,
                    createdDateText: createdDateText
                )

                ExpirationInfoSection(
                    countdownText: expirationService.countdownText(for: item),
                    detailText: expirationDetailText,
                    isPermanent: item.keepForever || item.expiresAt == .distantFuture
                )

                DetailActionSection(
                    isExporting: isExporting,
                    isAlreadySaved: item.wasExportedToPhotos,
                    folderName: folderName,
                    onSaveToPhotos: { exportToPhotos(memoryService: memoryService) },
                    onMoveToFolder: { isShowingFolderPicker = true },
                    onDelete: { isShowingDeleteConfirmation = true }
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save to Photos", isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                exportMessage = nil
            }
        } message: {
            Text(exportMessage ?? "")
        }
        .confirmationDialog("Delete this memory?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Memory", role: .destructive) {
                memoryService.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove it from Forgetful.")
        }
        .sheet(isPresented: $isShowingFolderPicker) {
            NavigationStack {
                FolderPickerSheet(
                    folders: folders,
                    selectedFolderID: item.folderId,
                    onSelect: { folderID in
                        memoryService.move(item, to: folderID)
                        isShowingFolderPicker = false
                    }
                )
            }
        }
    }

    private var folderName: String {
        if let folder = folders.first(where: { $0.id == item.folderId }) {
            return folder.name
        }
        return "Unsorted"
    }

    private var createdDateText: String {
        item.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var expirationDetailText: String {
        if item.keepForever || item.expiresAt == .distantFuture {
            return "This memory will stay in Forgetful until you delete it."
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(item.expiresAt) {
            return "Expires today at \(item.expiresAt.formatted(date: .omitted, time: .shortened))."
        }

        if calendar.isDateInTomorrow(item.expiresAt) {
            return "Expires tomorrow at \(item.expiresAt.formatted(date: .omitted, time: .shortened))."
        }

        return "Expires on \(item.expiresAt.formatted(date: .abbreviated, time: .shortened))."
    }

    private func exportToPhotos(memoryService: MemoryService) {
        guard !isExporting else { return }
        isExporting = true

        Task {
            defer { isExporting = false }

            guard let image = appManager.assetStore.loadOriginal(filename: item.imageFilename) else {
                exportMessage = PhotosExportError.assetMissing.localizedDescription
                return
            }

            do {
                try await photosExportService.export(image: image)
                memoryService.markExportedToPhotos(item)
                exportMessage = "Saved to Photos. This Forgetful item will still expire normally unless you extend or delete it."
            } catch {
                exportMessage = (error as? LocalizedError)?.errorDescription ?? "Forgetful couldn't save this image to Photos."
            }
        }
    }
}

private struct MemoryHeroImage: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.secondary.opacity(0.12))
                    .frame(height: 280)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct MemoryMetaCard: View {
    let item: MemoryItem
    let countdownText: String
    let folderName: String
    let createdDateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                CountdownBadge(text: countdownText)

                if item.wasExportedToPhotos {
                    Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let note = item.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(note)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            } else {
                Text("No note added")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                metadataRow(title: "Folder", value: folderName, symbol: "folder")
                metadataRow(title: "Captured", value: createdDateText, symbol: "calendar")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.quaternary.opacity(0.8), lineWidth: 1)
        )
    }

    private func metadataRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }
}

private struct ExpirationInfoSection: View {
    let countdownText: String
    let detailText: String
    let isPermanent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expires")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isPermanent ? "infinity.circle" : "clock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isPermanent ? "No expiration" : countdownText.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.quaternary.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct DetailActionSection: View {
    let isExporting: Bool
    let isAlreadySaved: Bool
    let folderName: String
    let onSaveToPhotos: () -> Void
    let onMoveToFolder: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Actions")
                .font(.headline)

            VStack(spacing: 10) {
                actionRow(
                    title: isExporting ? "Saving to Photos..." : "Save to Photos",
                    subtitle: isAlreadySaved ? "This memory was already exported. Saving again will create another copy." : "Copy the original image to your system photo library.",
                    symbol: isAlreadySaved ? "checkmark.circle.fill" : "square.and.arrow.down",
                    tint: .primary,
                    action: onSaveToPhotos
                )
                .disabled(isExporting)

                actionRow(
                    title: "Move to Folder",
                    subtitle: "Currently \(folderName)",
                    symbol: "folder",
                    tint: .secondary,
                    action: onMoveToFolder
                )

                actionRow(
                    title: "Delete Memory",
                    subtitle: "Remove it from Forgetful.",
                    symbol: "trash",
                    tint: .red,
                    isDestructive: true,
                    action: onDelete
                )
            }
        }
    }

    private func actionRow(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isDestructive ? .red : tint)
                    .frame(width: 38, height: 38)
                    .background((isDestructive ? Color.red : tint).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder((isDestructive ? Color.red.opacity(0.35) : Color.secondary.opacity(0.16)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FolderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let folders: [FolderEntity]
    let selectedFolderID: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        List {
            folderButton(title: "Unsorted", subtitle: "Keep this memory outside a folder", folderID: nil)

            ForEach(folders, id: \.id) { folder in
                folderButton(title: folder.name, subtitle: "Move into \(folder.name)", folderID: folder.id)
            }
        }
        .navigationTitle("Move to Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func folderButton(title: String, subtitle: String, folderID: UUID?) -> some View {
        Button {
            onSelect(folderID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: folderID == nil ? "tray" : "folder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedFolderID == folderID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
