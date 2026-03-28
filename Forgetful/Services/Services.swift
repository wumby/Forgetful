import Foundation
import Photos
import SwiftData
import UIKit

struct ExpirationService {
    func date(for preset: ExpirationPreset, from baseDate: Date = .now) -> Date {
        switch preset {
        case .oneDay:
            Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        case .threeDays:
            Calendar.current.date(byAdding: .day, value: 3, to: baseDate) ?? baseDate
        case .sevenDays:
            Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate
        case .thirtyDays:
            Calendar.current.date(byAdding: .day, value: 30, to: baseDate) ?? baseDate
        case .never:
            .distantFuture
        }
    }

    func preset(from rawValue: String) -> ExpirationPreset {
        ExpirationPreset(rawValue: rawValue) ?? .sevenDays
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

    func countdownText(for item: MemoryItem, now: Date = .now) -> String {
        if item.keepForever || item.expiresAt == .distantFuture {
            return "kept"
        }

        if item.expiresAt <= now {
            return "expired"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(item.expiresAt) {
            return "expires tonight"
        }

        if calendar.isDateInTomorrow(item.expiresAt) {
            return "tomorrow"
        }

        let dayCount = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: item.expiresAt)).day ?? 1)
        return "\(dayCount)d left"
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
    let context: ModelContext

    func createFolder(name: String, colorName: String?, iconName: String?) throws {
        let currentCount = (try? context.fetchCount(FetchDescriptor<FolderEntity>())) ?? 0
        let folder = FolderEntity(name: name, colorName: colorName, iconName: iconName, sortOrder: currentCount)
        context.insert(folder)
        try context.save()
    }

    func renameFolder(_ folder: FolderEntity, name: String) throws {
        folder.name = name
        try context.save()
    }

    func deleteFolder(_ folder: FolderEntity, moveItemsToUnsorted: Bool = true) throws {
        let memories = fetchItems(in: folder)
        if moveItemsToUnsorted {
            memories.forEach { $0.folderId = nil; $0.updatedAt = .now }
        }
        context.delete(folder)
        try context.save()
    }

    func activeItemCount(in folder: FolderEntity, expirationService: ExpirationService = ExpirationService()) -> Int {
        fetchItems(in: folder).filter { expirationService.isActive($0) }.count
    }

    func fetchItems(in folder: FolderEntity) -> [MemoryItem] {
        let folderID = folder.id
        let descriptor = FetchDescriptor<MemoryItem>(predicate: #Predicate { $0.folderId == folderID })
        return (try? context.fetch(descriptor)) ?? []
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
    }

    func move(_ item: MemoryItem, to folderId: UUID?) {
        item.folderId = folderId
        item.updatedAt = .now
        try? context.save()
    }

    func markExportedToPhotos(_ item: MemoryItem) {
        item.wasExportedToPhotos = true
        item.exportedToPhotosAt = .now
        item.updatedAt = .now
        try? context.save()
    }

    func delete(_ item: MemoryItem) {
        assetStore.deleteAssetFiles(imageFilename: item.imageFilename, thumbnailFilename: item.thumbnailFilename)
        context.delete(item)
        try? context.save()
    }

    func fetchActiveItems() -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).filter { expirationService.isActive($0) }
    }

    func fetchRecentItems(limit: Int) -> [MemoryItem] {
        Array(fetchActiveItems().prefix(limit))
    }

    func fetchExpiringSoonItems() -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>(sortBy: [SortDescriptor(\.expiresAt)])
        return ((try? context.fetch(descriptor)) ?? []).filter { expirationService.isExpiringSoon($0) }
    }

    func runExpirationCleanup(preferences: UserPreferences) {
        let descriptor = FetchDescriptor<MemoryItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        let expired = items.filter { item in
            !item.keepForever &&
            item.deletedAt == nil &&
            item.expiresAt <= .now
        }

        if preferences.autoDeleteExpired {
            expired.forEach(delete)
        } else {
            expired.forEach {
                $0.deletedAt = .now
                $0.updatedAt = .now
            }
            try? context.save()
        }

        preferences.lastCleanupDate = .now
        try? context.save()
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
            (.systemBlue, "Side gate code 3814", folders[1], .oneDay, false),
            (.systemGreen, "Level B2 near elevator C", folders[2], .sevenDays, false),
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
