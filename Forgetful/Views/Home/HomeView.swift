import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case library
    case capture
}

private enum LibraryMode: String, CaseIterable, Identifiable {
    case photos
    case folders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: "Photos"
        case .folders: "Folders"
        }
    }
}

private enum LibrarySort: Hashable {
    case newestFirst
    case oldestFirst
    case expiringSoonest

    var title: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        case .expiringSoonest: "Expiring Soonest"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: AppTab = .capture

    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureTabView(selectedTab: $selectedTab)
                .tag(AppTab.capture)
                .tabItem {
                    Label("Capture", systemImage: selectedTab == .capture ? "camera.fill" : "camera")
                }

            NavigationStack {
                LibraryView()
            }
            .tag(AppTab.library)
            .tabItem {
                Label("Mementos", systemImage: selectedTab == .library ? "photo.on.rectangle.fill" : "photo.on.rectangle")
            }
        }
        .tint(.primary)
    }
}

struct CaptureTabView: View {
    @Binding var selectedTab: AppTab

    @State private var isShowingCamera = false
    @State private var captureSession: CapturedImageSession?
    @State private var pendingSaveMessage: String?
    @State private var toastMessage: String?
    @State private var toastDismissTask: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if let toastMessage {
                    CaptureToastView(message: toastMessage)
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if selectedTab == .capture {
                isShowingCamera = true
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .capture, !isShowingCamera, captureSession == nil else { return }
            isShowingCamera = true
        }
        .sheet(isPresented: $isShowingCamera, onDismiss: handleCameraDismiss) {
            CameraCaptureView { image in
                captureSession = CapturedImageSession(image: image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $captureSession, onDismiss: handleSaveFlowDismiss) { session in
            NavigationStack {
                CaptureFlowView(image: session.image) { destinationName in
                    pendingSaveMessage = "Saved to \(destinationName)"
                }
            }
        }
    }

    private func handleCameraDismiss() {
        if captureSession == nil, selectedTab == .capture {
            selectedTab = .library
        }
    }

    private func handleSaveFlowDismiss() {
        captureSession = nil
        if let pendingSaveMessage {
            showToast(message: pendingSaveMessage)
            self.pendingSaveMessage = nil
        }
    }

    private func showToast(message: String) {
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            toastMessage = message
        }

        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                toastMessage = nil
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard selectedTab == .capture, captureSession == nil, !isShowingCamera else { return }
                isShowingCamera = true
            }
        }

        toastDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}

private struct CaptureToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]
    @State private var selectedMode: LibraryMode = .photos
    @State private var selectedSort: LibrarySort = .newestFirst
    @State private var isPresentingCreateFolder = false
    @State private var folderErrorMessage: String?

    private let expirationService = ExpirationService()

    private var allItems: [MemoryItem] {
        MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService).fetchActiveItems()
    }

    private var expiringSoonItems: [MemoryItem] {
        MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService).fetchExpiringSoonItems()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MementosHeader(subtitle: statusText, selectedMode: $selectedMode) {
                headerAccessory
            }

            Group {
                switch selectedMode {
                case .photos:
                    LibraryPhotosView(selectedSort: $selectedSort)
                        .environmentObject(appManager)
                case .folders:
                    LibraryFoldersView()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingCreateFolder) {
            FolderEditorSheet(title: "New Folder", submitTitle: "Create") { name, color, icon in
                do {
                    try FolderService(context: modelContext).createFolder(name: name, colorName: color, iconName: icon)
                } catch {
                    folderErrorMessage = error.localizedDescription
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

    private var statusText: String {
        switch selectedMode {
        case .photos:
            if expiringSoonItems.count > 0 {
                return "\(allItems.count) active memories, \(expiringSoonItems.count) expiring soon"
            }
            return "\(allItems.count) active memories"
        case .folders:
            return folders.count == 1 ? "1 folder" : "\(folders.count) folders"
        }
    }

    private func sortButton(_ sort: LibrarySort) -> some View {
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

    @ViewBuilder
    private var headerAccessory: some View {
        switch selectedMode {
        case .photos:
            Menu {
                Section("Sort") {
                    sortButton(.newestFirst)
                    sortButton(.oldestFirst)
                    sortButton(.expiringSoonest)
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        case .folders:
            Button {
                isPresentingCreateFolder = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add folder")
        }
    }
}

private struct MementosHeader<Accessory: View>: View {
    let subtitle: String
    @Binding var selectedMode: LibraryMode
    let accessory: () -> Accessory

    init(
        subtitle: String,
        selectedMode: Binding<LibraryMode>,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.subtitle = subtitle
        self._selectedMode = selectedMode
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mementos")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                accessory()
                    .frame(minWidth: 86, alignment: .trailing)
            }

            Picker("Browse", selection: $selectedMode) {
                ForEach(LibraryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

private struct LibraryPhotosView: View {
    @Binding var selectedSort: LibrarySort

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]

    private let expirationService = ExpirationService()

    private var memoryService: MemoryService {
        MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)
    }

    private var allItems: [MemoryItem] {
        memoryService.fetchActiveItems()
    }

    private var expiringSoonItems: [MemoryItem] {
        memoryService.fetchExpiringSoonItems()
    }

    private var displayedItems: [MemoryItem] {
        sort(allItems)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(sortSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if displayedItems.isEmpty {
                        CompactEmptyStateView(
                            title: emptyStateTitle,
                            message: emptyStateMessage,
                            symbol: emptyStateSymbol
                        )
                    } else {
                        MemoryCardGrid(
                            items: displayedItems,
                            assetStore: appManager.assetStore,
                            expirationService: expirationService
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private var sortSummaryText: String {
        "Sorted by \(selectedSort.title.localizedLowercase)"
    }

    private var emptyStateTitle: String {
        return "No memories yet"
    }

    private var emptyStateMessage: String {
        return "Your temporary captures will appear here."
    }

    private var emptyStateSymbol: String {
        return "photo.on.rectangle"
    }

    private func sort(_ items: [MemoryItem]) -> [MemoryItem] {
        switch selectedSort {
        case .newestFirst:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .expiringSoonest:
            return items.sorted { lhs, rhs in
                let lhsDate = lhs.keepForever ? Date.distantFuture : lhs.expiresAt
                let rhsDate = rhs.keepForever ? Date.distantFuture : rhs.expiresAt
                if lhsDate == rhsDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsDate < rhsDate
            }
        }
    }
}

private struct LibraryFoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]

    @State private var deleteFolder: FolderEntity?
    @State private var folderErrorMessage: String?

    private let expirationService = ExpirationService()

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
                    NavigationLink {
                        FolderDetailView(folder: folder)
                    } label: {
                        FolderRowCell(
                            folder: folder,
                            count: FolderService(context: modelContext).activeItemCount(in: folder, expirationService: expirationService)
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteFolder = folder
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.plain)
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
            Text("Memories in this folder will stay in Forgetful and be moved to Unsorted.")
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

                Text(count == 1 ? "1 active memory" : "\(count) active memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
