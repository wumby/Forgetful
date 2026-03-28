import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case library
    case capture
    case settings
}

private enum LibraryFilter: Hashable {
    case all
    case expiringSoon
    case unsorted

    var title: String {
        switch self {
        case .all: "All"
        case .expiringSoon: "Expiring Soon"
        case .unsorted: "Unsorted"
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
    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var selectedFolderID: UUID?

    private let expirationService = ExpirationService()

    private var memoryService: MemoryService {
        MemoryService(context: modelContext, assetStore: appManager.assetStore, expirationService: expirationService)
    }

    private var expiringSoonItems: [MemoryItem] {
        memoryService.fetchExpiringSoonItems()
    }

    private var folderLookup: [UUID: FolderEntity] {
        Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
    }

    private var folderCounts: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: folders.map { folder in
            (folder.id, FolderService(context: modelContext).activeItemCount(in: folder, expirationService: expirationService))
        })
    }

    private var allItems: [MemoryItem] {
        memoryService.fetchActiveItems()
    }

    private var filteredItems: [MemoryItem] {
        let filteredByScope = allItems.filter(matchesContext)
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return filteredByScope
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return filteredByScope.filter { item in
            let noteMatches = item.note?.localizedLowercase.contains(query) == true
            let folderMatches = folderName(for: item)?.localizedLowercase.contains(query) == true
            return noteMatches || folderMatches
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                if expiringSoonItems.count > 0, selectedFilter != .expiringSoon, selectedFolderID == nil {
                    Button {
                        selectedFilter = .expiringSoon
                    } label: {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                            Text("\(expiringSoonItems.count) memories expiring soon")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }

                if !folders.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Folders")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        NavigationLink {
                            FolderListView()
                        } label: {
                            Text("See All")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(folders, id: \.id) { folder in
                                Button {
                                    selectedFolderID = folder.id
                                } label: {
                                    FolderBrowseCard(
                                        folder: folder,
                                        count: folderCounts[folder.id] ?? 0,
                                        isSelected: selectedFolderID == folder.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterChip(title: "All", filter: .all)
                        filterChip(title: "Expiring Soon", filter: .expiringSoon)
                        filterChip(title: "Unsorted", filter: .unsorted)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gridTitle)
                            .font(.title3.weight(.semibold))

                        Text(gridSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if filteredItems.isEmpty {
                        CompactEmptyStateView(
                            title: emptyStateTitle,
                            message: emptyStateMessage,
                            symbol: emptyStateSymbol
                        )
                    } else {
                        MemoryCardGrid(
                            items: filteredItems,
                            assetStore: appManager.assetStore,
                            expirationService: expirationService,
                            folderNameProvider: gridFolderName(for:)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search notes or folders")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusText: String {
        if let selectedFolderName {
            return "\(filteredItems.count) memories in \(selectedFolderName)"
        }
        if expiringSoonItems.count > 0 {
            return "\(allItems.count) active memories, \(expiringSoonItems.count) expiring soon"
        }
        return "\(allItems.count) active memories"
    }

    private var gridTitle: String {
        selectedFolderName ?? filterTitle
    }

    private var gridSubtitle: String {
        let count = filteredItems.count
        return count == 1 ? "1 memory" : "\(count) memories"
    }

    private var filterTitle: String {
        switch selectedFilter {
        case .all:
            return "All"
        case .expiringSoon:
            return "Expiring Soon"
        case .unsorted:
            return "Unsorted"
        }
    }

    private var selectedFolderName: String? {
        guard let selectedFolderID else { return nil }
        return folderLookup[selectedFolderID]?.name
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No results"
        }

        if selectedFolderID != nil {
            return "No memories in this folder"
        }

        switch selectedFilter {
        case .all:
            return "No memories yet"
        case .expiringSoon:
            return "Nothing expiring soon"
        case .unsorted:
            return "Nothing unsorted"
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try a different note or folder search."
        }

        if selectedFolderID != nil {
            return "Capture something new or move memories into this folder."
        }

        switch selectedFilter {
        case .all:
            return "Your temporary captures will appear here."
        case .expiringSoon:
            return "Items due within the next 24 hours show up here."
        case .unsorted:
            return "Memories without a folder will collect here."
        }
    }

    private var emptyStateSymbol: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        }

        if selectedFolderID != nil {
            return "folder"
        }

        switch selectedFilter {
        case .all:
            return "photo.on.rectangle"
        case .expiringSoon:
            return "clock.badge.checkmark"
        case .unsorted:
            return "tray"
        }
    }

    private func filterChip(title: String, filter: LibraryFilter) -> some View {
        Button {
            selectedFolderID = nil
            selectedFilter = filter
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    selectedFilter == filter ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func matchesContext(_ item: MemoryItem) -> Bool {
        if let selectedFolderID {
            return item.folderId == selectedFolderID
        }

        switch selectedFilter {
        case .all:
            return true
        case .expiringSoon:
            return expirationService.isExpiringSoon(item)
        case .unsorted:
            return item.folderId == nil
        }
    }

    private func folderName(for item: MemoryItem) -> String? {
        guard let folderID = item.folderId else { return nil }
        return folderLookup[folderID]?.name
    }

    private func gridFolderName(for item: MemoryItem) -> String? {
        guard selectedFolderID == nil else { return nil }
        return folderName(for: item)
    }
}
