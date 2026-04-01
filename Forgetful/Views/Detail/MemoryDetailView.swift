import SwiftData
import SwiftUI
import UIKit

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
    @State private var isShowingImageViewer = false
    @State private var shareURL: URL?
    @State private var shareErrorMessage: String?

    private let expirationService = ExpirationService()
    private let photosExportService = PhotosExportService()

    var body: some View {
        let memoryService = MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MemoryHeroImage(
                    image: appManager.assetStore.loadOriginal(filename: item.imageFilename),
                    onTap: {
                        isShowingImageViewer = true
                    }
                )

                MemoryMetaCard(
                    item: item,
                    expirationDetailText: expirationDetailText,
                    folderName: folderName,
                    createdDateText: createdDateText
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        sharePhoto()
                    } label: {
                        Label("Share Memento", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        exportToPhotos(memoryService: memoryService)
                    } label: {
                        Label(isExporting ? "Saving to Photos..." : (item.wasExportedToPhotos ? "Save to Photos Again" : "Save to Photos"), systemImage: item.wasExportedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                    }
                    .disabled(isExporting)

                    Button {
                        isShowingFolderPicker = true
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }

                    Divider()

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Text("Delete Memento")
                            Spacer()
                            Image(uiImage: tintedDeleteMemoryIcon)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Memory actions")
            }
        }
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
        .alert("Share Memento", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "")
        }
        .confirmationDialog("Delete this memento?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Memento", role: .destructive) {
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
        .fullScreenCover(isPresented: $isShowingImageViewer) {
            if let image = appManager.assetStore.loadOriginal(filename: item.imageFilename) {
                FullScreenMemoryImageViewer(image: image)
            }
        }
        .sheet(item: $shareURL, onDismiss: cleanupSharedFile) { url in
            ActivityViewController(activityItems: [url]) {
                cleanupSharedFile()
            }
        }
    }

    private var folderName: String {
        if let folder = folders.first(where: { $0.id == item.folderId }) {
            return folder.name
        }
        return "No Folder"
    }

    private var createdDateText: String {
        item.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var expirationDetailText: String {
        if item.keepForever || item.expiresAt == .distantFuture {
            return "No expiration"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(item.expiresAt) {
            return "Today at \(item.expiresAt.formatted(date: .omitted, time: .shortened))"
        }

        if calendar.isDateInTomorrow(item.expiresAt) {
            return "Tomorrow at \(item.expiresAt.formatted(date: .omitted, time: .shortened))"
        }

        return item.expiresAt.formatted(date: .abbreviated, time: .shortened)
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
                exportMessage = "Saved to Photos. This memento will still expire in Forgetful on schedule."
            } catch {
                exportMessage = (error as? LocalizedError)?.errorDescription ?? "Forgetful couldn't save this image to Photos."
            }
        }
    }

    private func sharePhoto() {
        let fileURL = appManager.assetStore.originalFileURL(filename: item.imageFilename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            shareErrorMessage = "The original image could not be loaded."
            return
        }

        do {
            let sharedURL = try prepareShareURL(from: fileURL)
            shareURL = sharedURL
        } catch {
            shareErrorMessage = "This photo couldn't be prepared for sharing."
        }
    }

    private func prepareShareURL(from originalURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let shareDirectory = fileManager.temporaryDirectory.appendingPathComponent("ForgetfulShares", isDirectory: true)

        if !fileManager.fileExists(atPath: shareDirectory.path) {
            try fileManager.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
        }

        let destinationURL = shareDirectory.appendingPathComponent("\(item.id.uuidString).jpg")

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: originalURL, to: destinationURL)
        return destinationURL
    }

    private func cleanupSharedFile() {
        guard let shareURL else { return }
        try? FileManager.default.removeItem(at: shareURL)
        self.shareURL = nil
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private var tintedDeleteMemoryIcon: UIImage {
    let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
    return UIImage(systemName: "trash", withConfiguration: configuration)?
        .withTintColor(.systemRed, renderingMode: .alwaysOriginal) ?? UIImage()
}

private struct MemoryHeroImage: View {
    let image: UIImage?
    let onTap: () -> Void

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture(perform: onTap)
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
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }
}

private struct FullScreenMemoryImageViewer: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissOffsetY: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topTrailing) {
                Color.black
                    .ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(x: clampedOffset(in: size).width, y: clampedOffset(in: size).height + dismissOffsetY)
                    .frame(width: size.width, height: size.height)
                    .gesture(doubleTapGesture)
                    .simultaneousGesture(magnifyGesture(in: size))
                    .simultaneousGesture(dragGesture(in: size))
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: scale)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: offset)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dismissOffsetY)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(.top, 18)
                .padding(.trailing, 18)
            }
        }
        .statusBarHidden()
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                if scale > 1.05 {
                    resetZoom()
                } else {
                    scale = 2.5
                }
            }
        }
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let nextScale = min(max(lastScale * value.magnification, 1), 4)
                scale = nextScale
                if scale <= 1.01 {
                    offset = .zero
                } else {
                    offset = clamped(offset: offset, in: size, scale: scale)
                }
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        resetZoom()
                    }
                } else {
                    let clamped = clamped(offset: offset, in: size, scale: scale)
                    offset = clamped
                    lastOffset = clamped
                }
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.01 {
                    let nextOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    offset = clamped(offset: nextOffset, in: size, scale: scale)
                } else {
                    dismissOffsetY = max(value.translation.height, 0)
                }
            }
            .onEnded { value in
                if scale > 1.01 {
                    let nextOffset = clamped(offset: offset, in: size, scale: scale)
                    offset = nextOffset
                    lastOffset = nextOffset
                } else if dismissOffsetY > 120 || value.predictedEndTranslation.height > 180 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        dismissOffsetY = 0
                    }
                }
            }
    }

    private func clampedOffset(in size: CGSize) -> CGSize {
        clamped(offset: offset, in: size, scale: scale)
    }

    private func clamped(offset: CGSize, in size: CGSize, scale: CGFloat) -> CGSize {
        guard scale > 1 else { return .zero }

        let horizontalLimit = (size.width * (scale - 1)) / 2
        let verticalLimit = (size.height * (scale - 1)) / 2

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
        dismissOffsetY = 0
    }
}

private struct MemoryMetaCard: View {
    let item: MemoryItem
    let expirationDetailText: String
    let folderName: String
    let createdDateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if item.wasExportedToPhotos {
                Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            metadataSection(title: "Time") {
                metadataRow(
                    title: "Date Taken",
                    value: createdDateText,
                    symbol: "calendar",
                    valueFont: .subheadline.weight(.semibold)
                )
                metadataRow(
                    title: "Expires",
                    value: expirationDetailText,
                    symbol: "hourglass",
                    valueFont: .subheadline.weight(.semibold)
                )
            }

            Divider()
                .overlay(.quaternary.opacity(0.7))

            metadataSection(title: "Context") {
                if let noteText {
                    metadataRow(title: "Note", value: noteText, symbol: "note.text")
                }
                metadataRow(title: "Folder", value: folderName, symbol: "folder")
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

    private func metadataSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                content()
            }
        }
    }

    private func metadataRow(title: String, value: String, symbol: String, valueFont: Font = .subheadline.weight(.medium)) -> some View {
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
                    .font(valueFont)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }

    private var noteText: String? {
        guard let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }
        return note
    }
}

private struct FolderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let folders: [FolderEntity]
    let selectedFolderID: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        List {
            folderButton(
                title: "No Folder",
                subtitle: "Keep this memory outside folders",
                symbol: "tray",
                tint: .secondary,
                folderID: nil
            )

            ForEach(folders, id: \.id) { folder in
                folderButton(
                    title: folder.name,
                    subtitle: "Move into \(folder.name)",
                    symbol: folder.iconName ?? "folder",
                    tint: Color(folderColorName: folder.colorName),
                    folderID: folder.id
                )
            }
        }
        .listStyle(.plain)
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

    private func folderButton(title: String, subtitle: String, symbol: String, tint: Color, folderID: UUID?) -> some View {
        Button {
            onSelect(folderID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(folderID == nil ? 0.1 : 0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedFolderID == folderID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
