import SwiftData
import SwiftUI

struct FolderDetailView: View {
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var allItems: [MemoryItem]

    let folder: FolderEntity?

    @State private var isShowingCamera = false
    @State private var captureSession: CapturedImageSession?
    @State private var selectedSort: MemorySort = .newestFirst

    private let expirationService = ExpirationService()

    private var items: [MemoryItem] {
        allItems.filter { item in
            expirationService.isActive(item) && item.folderId == folder?.id
        }
    }

    private var displayedItems: [MemoryItem] {
        items.sortedMementos(using: selectedSort)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if items.isEmpty {
                    compactEmptyState
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .overlay(.quaternary.opacity(0.7))

                        HStack(alignment: .center, spacing: 12) {
                            Text(itemCountText)
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
                        .padding(.top, 4)
                    }

                    MemoryCardGrid(
                        items: displayedItems,
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: folder?.iconName ?? "tray")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(folderColorName: folder?.colorName))

                    Text(folder?.name ?? "No Folder")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }
            }

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
        .sheet(item: $captureSession, onDismiss: handleCaptureFlowDismiss) { session in
            NavigationStack {
                CaptureFlowView(
                    image: session.image,
                    preselectedFolderID: folder?.id
                )
            }
        }
    }

    private var itemCountText: String {
        items.count == 1 ? "1 memento" : "\(items.count) mementos"
    }

    private func handleCaptureFlowDismiss() {
        captureSession = nil
    }

    private var sortLabel: String {
        switch selectedSort {
        case .newestFirst:
            "Newest"
        case .oldestFirst:
            "Oldest"
        case .expiringSoonest:
            "Expiring Soonest"
        }
    }

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
    let onSubmit: (String, String?, String?) -> Bool

    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "folder"
    @FocusState private var isNameFieldFocused: Bool

    private let maxNameLength = FolderService.maxNameLength

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
                        .focused($isNameFieldFocused)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > maxNameLength {
                                name = String(newValue.prefix(maxNameLength))
                            }
                        }
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
                        let didSubmit = onSubmit(name.trimmingCharacters(in: .whitespacesAndNewlines), selectedColor, selectedIcon)
                        if didSubmit {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            name = initialName
            selectedColor = initialColorName ?? "blue"
            selectedIcon = initialIconName ?? "folder"
            DispatchQueue.main.async {
                isNameFieldFocused = true
            }
        }
    }
}
