import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case library
    case capture
    case settings
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
    @State private var selectedTab: AppTab = .library

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView()
            }
            .tag(AppTab.library)
            .tabItem {
                Label("Library", systemImage: selectedTab == .library ? "photo.on.rectangle.fill" : "photo.on.rectangle")
            }

            CaptureTabView(selectedTab: $selectedTab)
                .tag(AppTab.capture)
                .tabItem {
                    Label("Capture", systemImage: selectedTab == .capture ? "camera.fill" : "camera")
                }

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.settings)
            .tabItem {
                Label("Settings", systemImage: selectedTab == .settings ? "gearshape.fill" : "gearshape")
            }
        }
        .tint(.primary)
    }
}

struct CaptureTabView: View {
    @Binding var selectedTab: AppTab

    @State private var isShowingCamera = false
    @State private var captureSession: CapturedImageSession?
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Capture")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Open the camera fast, save the memory, and let Forgetful handle the rest.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 58, height: 58)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                    Text("Ready to capture")
                        .font(.title3.weight(.semibold))

                    Text("Use Forgetful for parking spots, codes, receipts, whiteboards, and anything else you only need for a little while.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Open Camera") {
                        isShowingCamera = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.quaternary.opacity(0.8), lineWidth: 1)
                )

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if selectedTab == .capture {
                isShowingCamera = true
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .capture, !isShowingCamera, captureSession == nil else { return }
            isShowingCamera = true
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                captureSession = CapturedImageSession(image: image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $captureSession) { session in
            NavigationStack {
                CaptureFlowView(image: session.image)
            }
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager
    @Query(sort: \FolderEntity.sortOrder) private var folders: [FolderEntity]
    @State private var selectedMode: LibraryMode = .photos
    @State private var selectedSort: LibrarySort = .newestFirst

    private let expirationService = ExpirationService()

    private var allItems: [MemoryItem] {
        MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService).fetchActiveItems()
    }

    private var expiringSoonItems: [MemoryItem] {
        MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService).fetchExpiringSoonItems()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            HStack(spacing: 12) {
                Picker("Browse", selection: $selectedMode) {
                    ForEach(LibraryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

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
                .opacity(selectedMode == .photos ? 1 : 0)
                .allowsHitTesting(selectedMode == .photos)
                .accessibilityHidden(selectedMode != .photos)
            }
            .padding(.horizontal, 20)

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
            .padding(.bottom, 20)
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

    @State private var isPresentingCreate = false
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
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            deleteFolder = folder
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add folder")
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
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(count == 1 ? "1 active memory" : "\(count) active memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
