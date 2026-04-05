import Foundation
import Photos
import SwiftData
import SwiftUI
import UIKit

struct ExpirationService {
    enum LibraryBadgeTone {
        case urgent
        case tomorrow
        case warning
        case calm
        case archived
    }

    func date(for preset: ExpirationPreset, from baseDate: Date = .now) -> Date {
        switch preset {
        case .threeDays:
            Calendar.current.date(byAdding: .day, value: 3, to: baseDate) ?? baseDate
        case .sevenDays:
            Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate
        case .fourteenDays:
            Calendar.current.date(byAdding: .day, value: 14, to: baseDate) ?? baseDate
        case .thirtyDays:
            Calendar.current.date(byAdding: .day, value: 30, to: baseDate) ?? baseDate
        case .never:
            .distantFuture
        }
    }

    func preset(from rawValue: String) -> ExpirationPreset {
        if rawValue == "1d" {
            return .sevenDays
        }
        return ExpirationPreset(rawValue: rawValue) ?? .sevenDays
    }

    func isExpiringSoon(_ item: MemoryItem, now: Date = .now) -> Bool {
        guard !item.keepForever, item.deletedAt == nil else { return false }
        return item.expiresAt > now && item.expiresAt <= now.addingTimeInterval(24 * 60 * 60)
    }

    func isActive(_ item: MemoryItem, now: Date = .now) -> Bool {
        guard item.deletedAt == nil else { return false }
        if item.keepForever { return true }
        return item.expiresAt > now
    }

    func libraryBadgeText(for item: MemoryItem, now: Date = .now) -> String {
        if item.keepForever || item.expiresAt == .distantFuture {
            return "Kept"
        }

        if item.expiresAt <= now {
            return "Expired"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(item.expiresAt) {
            let hoursLeft = max(1, Int(ceil(item.expiresAt.timeIntervalSince(now) / 3600)))
            return "\(hoursLeft)h left"
        }

        if calendar.isDateInTomorrow(item.expiresAt) {
            return "1d left"
        }

        let dayCount = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: item.expiresAt)).day ?? 1)
        return "\(dayCount)d left"
    }

    func libraryBadgeTone(for item: MemoryItem, now: Date = .now) -> LibraryBadgeTone {
        if item.keepForever || item.expiresAt == .distantFuture {
            return .archived
        }

        if item.expiresAt <= now {
            return .urgent
        }

        let calendar = Calendar.current
        if calendar.isDateInTomorrow(item.expiresAt) {
            return .tomorrow
        }

        let dayCount = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: item.expiresAt)).day ?? 0)

        switch dayCount {
        case 0:
            return .urgent
        case 1:
            return .tomorrow
        case 2...3:
            return .warning
        default:
            return .calm
        }
    }
}

struct PhotosExportService {
    func export(image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotosExportError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotosExportError.exportFailed)
                }
            }
        }
    }
}

@MainActor
struct MementoRenderService {
    let expirationService: ExpirationService

    func renderImage(for item: MemoryItem, image: UIImage) -> UIImage? {
        let content = MemoryPolaroidCard(
            image: image,
            note: item.note,
            createdAt: item.createdAt,
            badgeText: expirationService.libraryBadgeText(for: item),
            badgeTone: expirationService.libraryBadgeTone(for: item),
            style: .export,
            showsBadge: false
        )
        .frame(width: 1320)
        .padding(28)
        .background(Color.clear)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1376, height: nil)
        return renderer.uiImage
    }
}

enum PhotosExportError: LocalizedError {
    case permissionDenied
    case exportFailed
    case assetMissing

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photos access was denied. You can keep using Forgetful normally, or allow access in Settings."
        case .exportFailed:
            return "Forgetful couldn't save this image to Photos."
        case .assetMissing:
            return "The original image could not be loaded."
        }
    }
}

@MainActor
struct FolderService {
    static let maxNameLength = 24
    static let maxFolderCount = 20

    let context: ModelContext

    func ensureDefaultFolders() {
        let preferences = UserPreferences.fetchOrCreate(in: context)
        if preferences.hasCompletedInitialFolderSeed == true {
            return
        }

        let descriptor = FetchDescriptor<FolderEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        let existingFolders = (try? context.fetch(descriptor)) ?? []

        if preferences.hasCompletedInitialFolderSeed == nil && !existingFolders.isEmpty {
            preferences.hasCompletedInitialFolderSeed = true
        } else if existingFolders.isEmpty {
            let defaults: [(name: String, color: String, icon: String)] = [
                ("Home", "blue", "house"),
                ("Travel", "teal", "airplane"),
                ("Info", "orange", "info.circle")
            ]

            for (index, folder) in defaults.enumerated() {
                let entity = FolderEntity(
                    name: folder.name,
                    colorName: folder.color,
                    iconName: folder.icon,
                    sortOrder: index
                )
                context.insert(entity)
            }

            preferences.hasCompletedInitialFolderSeed = true
        }

        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    func createFolder(name: String, colorName: String?, iconName: String?) throws {
        let currentCount = (try? context.fetchCount(FetchDescriptor<FolderEntity>())) ?? 0
        guard currentCount < Self.maxFolderCount else {
            throw FolderServiceError.folderLimitReached
        }
        let sanitizedName = sanitizedFolderName(from: name)
        guard !sanitizedName.isEmpty else {
            throw FolderServiceError.invalidName
        }
        guard !folderNameExists(sanitizedName) else {
            throw FolderServiceError.duplicateName
        }
        let folder = FolderEntity(name: sanitizedName, colorName: colorName, iconName: iconName, sortOrder: currentCount)
        context.insert(folder)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw FolderServiceError.saveFailed
        }
    }

    func renameFolder(_ folder: FolderEntity, name: String) throws {
        let sanitizedName = sanitizedFolderName(from: name)
        guard !sanitizedName.isEmpty else {
            throw FolderServiceError.invalidName
        }
        guard !folderNameExists(sanitizedName, excluding: folder.id) else {
            throw FolderServiceError.duplicateName
        }
        folder.name = sanitizedName
        do {
            try context.save()
        } catch {
            context.rollback()
            throw FolderServiceError.saveFailed
        }
    }

    func deleteFolder(_ folder: FolderEntity, moveItemsToUnsorted: Bool = true) throws {
        let memories = fetchItems(in: folder)
        if moveItemsToUnsorted {
            memories.forEach { $0.folderId = nil; $0.updatedAt = .now }
        }
        context.delete(folder)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw FolderServiceError.deleteFailed
        }
    }

    func updateSortOrder(folderIDs: [UUID]) throws {
        let descriptor = FetchDescriptor<FolderEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        let folders = (try? context.fetch(descriptor)) ?? []
        let foldersByID = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var nextSortOrder = 0

        for folderID in folderIDs {
            guard let folder = foldersByID[folderID] else { continue }
            folder.sortOrder = nextSortOrder
            nextSortOrder += 1
        }

        for folder in folders where !folderIDs.contains(folder.id) {
            folder.sortOrder = nextSortOrder
            nextSortOrder += 1
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw FolderServiceError.saveFailed
        }
    }

    func activeItemCount(in folder: FolderEntity, expirationService: ExpirationService = ExpirationService()) -> Int {
        fetchItems(in: folder).filter { expirationService.isActive($0) }.count
    }

    func activeItemCounts(expirationService: ExpirationService = ExpirationService()) -> [UUID: Int] {
        let descriptor = FetchDescriptor<MemoryItem>()
        let items = ((try? context.fetch(descriptor)) ?? []).filter { expirationService.isActive($0) }

        return items.reduce(into: [:]) { counts, item in
            guard let folderId = item.folderId else { return }
            counts[folderId, default: 0] += 1
        }
    }

    func fetchItems(in folder: FolderEntity) -> [MemoryItem] {
        let folderID = folder.id
        let descriptor = FetchDescriptor<MemoryItem>(predicate: #Predicate { $0.folderId == folderID })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func sanitizedFolderName(from name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmedName.prefix(Self.maxNameLength))
    }

    private func folderNameExists(_ name: String, excluding folderID: UUID? = nil) -> Bool {
        let descriptor = FetchDescriptor<FolderEntity>()
        let normalizedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return ((try? context.fetch(descriptor)) ?? []).contains { folder in
            guard folder.id != folderID else { return false }
            let existingName = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return existingName == normalizedName
        }
    }
}

enum FolderServiceError: LocalizedError {
    case invalidName
    case duplicateName
    case folderLimitReached
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Folder names can't be empty."
        case .duplicateName:
            return "A folder with that name already exists."
        case .folderLimitReached:
            return "You've reached the maximum of 20 folders."
        case .saveFailed:
            return "This folder couldn't be saved. Try again."
        case .deleteFailed:
            return "This folder couldn't be deleted. Try again."
        }
    }
}

enum MemoryServiceError: LocalizedError {
    case saveFailed
    case deleteFailed
    case moveFailed
    case noteUpdateFailed
    case exportStateUpdateFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "This memento couldn't be saved. Try again."
        case .deleteFailed:
            return "This memento couldn't be deleted. Try again."
        case .moveFailed:
            return "This memento couldn't be moved. Try again."
        case .noteUpdateFailed:
            return "This note couldn't be updated. Try again."
        case .exportStateUpdateFailed:
            return "Forgetful saved the photo to Photos, but couldn't update its saved state."
        }
    }
}

@MainActor
struct MemoryService {
    let context: ModelContext
    let assetStore: AssetStore
    let expirationService: ExpirationService

    func createCaptureItem(
        image: UIImage,
        note: String,
        folderId: UUID?,
        expirationPreset: ExpirationPreset
    ) throws {
        let savedAsset = try assetStore.save(image: image)

        do {
            let item = MemoryItem(
                imageFilename: savedAsset.imageFilename,
                thumbnailFilename: savedAsset.thumbnailFilename,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                expiresAt: expirationService.date(for: expirationPreset),
                folderId: folderId,
                keepForever: expirationPreset == .never
            )
            context.insert(item)
            try context.save()
        } catch {
            assetStore.deleteAssetFiles(
                imageFilename: savedAsset.imageFilename,
                thumbnailFilename: savedAsset.thumbnailFilename
            )
            throw (error as? LocalizedError) ?? MemoryServiceError.saveFailed
        }
    }

    func move(_ item: MemoryItem, to folderId: UUID?) throws {
        item.folderId = folderId
        item.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw MemoryServiceError.moveFailed
        }
    }

    func updateNote(_ item: MemoryItem, note: String) throws {
        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw MemoryServiceError.noteUpdateFailed
        }
    }

    func markExportedToPhotos(_ item: MemoryItem) throws {
        item.wasExportedToPhotos = true
        item.exportedToPhotosAt = .now
        item.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw MemoryServiceError.exportStateUpdateFailed
        }
    }

    func delete(_ item: MemoryItem) throws {
        let imageFilename = item.imageFilename
        let thumbnailFilename = item.thumbnailFilename
        context.delete(item)
        do {
            try context.save()
            assetStore.deleteAssetFiles(imageFilename: imageFilename, thumbnailFilename: thumbnailFilename)
        } catch {
            context.rollback()
            throw MemoryServiceError.deleteFailed
        }
    }

    func fetchActiveItems() -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).filter { expirationService.isActive($0) }
    }

    func runExpirationCleanup(lastCleanupTracker: UserPreferences) {
        let descriptor = FetchDescriptor<MemoryItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        let expired = items.filter { item in
            !item.keepForever &&
            item.deletedAt == nil &&
            item.expiresAt <= .now
        }

        expired.forEach { item in
            try? delete(item)
        }

        lastCleanupTracker.lastCleanupDate = .now
        try? context.save()
    }
}

extension Array where Element == MemoryItem {
    func sortedMementos(using sort: MemorySort) -> [MemoryItem] {
        switch sort {
        case .newestFirst:
            return sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return sorted { $0.createdAt < $1.createdAt }
        case .expiringSoonest:
            return sorted { lhs, rhs in
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

enum SeedDataService {
    @MainActor
    static func seedIfNeeded(in context: ModelContext, assetStore: AssetStore) {
        let folderCount = (try? context.fetchCount(FetchDescriptor<FolderEntity>())) ?? 0
        let itemCount = (try? context.fetchCount(FetchDescriptor<MemoryItem>())) ?? 0
        guard folderCount == 0, itemCount == 0 else { return }

        let folders = [
            FolderEntity(name: "Errands", colorName: "orange", iconName: "cart"),
            FolderEntity(name: "Home", colorName: "blue", iconName: "house"),
            FolderEntity(name: "Parking", colorName: "green", iconName: "car")
        ]
        folders.enumerated().forEach { index, folder in
            folder.sortOrder = index
            context.insert(folder)
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1200))
        let configs: [(UIColor, String, FolderEntity?, ExpirationPreset, Bool)] = [
            (.systemOrange, "Receipt for lamp return", folders[0], .threeDays, false),
            (.systemBlue, "Side gate code 3814", folders[1], .sevenDays, false),
            (.systemGreen, "Level B2 near elevator C", folders[2], .fourteenDays, false),
            (.systemGray, "Product to compare later", folders[1], .thirtyDays, true)
        ]

        for config in configs {
            let image = renderer.image { context in
                config.0.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1200))
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 68, weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let textRect = CGRect(x: 120, y: 450, width: 960, height: 300)
                config.1.draw(in: textRect, withAttributes: attrs)
            }

            guard let savedAsset = try? assetStore.save(image: image) else { continue }
            let item = MemoryItem(
                imageFilename: savedAsset.imageFilename,
                thumbnailFilename: savedAsset.thumbnailFilename,
                note: config.1,
                expiresAt: ExpirationService().date(for: config.3),
                folderId: config.2?.id,
                keepForever: config.3 == .never,
                wasExportedToPhotos: config.4,
                exportedToPhotosAt: config.4 ? .now.addingTimeInterval(-3600) : nil
            )
            context.insert(item)
        }

        _ = UserPreferences.fetchOrCreate(in: context)
        try? context.save()
    }
}
