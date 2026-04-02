import Foundation
import SwiftData

enum ExpirationPreset: String, CaseIterable, Codable, Identifiable {
    case threeDays = "3d"
    case sevenDays = "7d"
    case fourteenDays = "14d"
    case thirtyDays = "30d"
    case never = "never"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeDays: "3 days"
        case .sevenDays: "7 days"
        case .fourteenDays: "14 days"
        case .thirtyDays: "30 days"
        case .never: "Never"
        }
    }

    var settingsTitle: String {
        switch self {
        case .threeDays: "3 Days"
        case .sevenDays: "7 Days"
        case .fourteenDays: "14 Days"
        case .thirtyDays: "1 Month"
        case .never: "Never"
        }
    }
}

enum MemorySort: Hashable {
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

    var shortTitle: String {
        switch self {
        case .newestFirst: "Newest"
        case .oldestFirst: "Oldest"
        case .expiringSoonest: "Expiring Soonest"
        }
    }
}

@Model
final class FolderEntity {
    var id: UUID
    var name: String
    var createdAt: Date
    var colorName: String?
    var iconName: String?
    var sortOrder: Int
    var isSystemFolder: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        colorName: String? = nil,
        iconName: String? = nil,
        sortOrder: Int = 0,
        isSystemFolder: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.colorName = colorName
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isSystemFolder = isSystemFolder
    }
}

@Model
final class MemoryItem {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var imageFilename: String
    var thumbnailFilename: String
    var note: String?
    var expiresAt: Date
    // Kept for model compatibility with earlier builds; no longer used by product behavior.
    var isArchived: Bool
    var folderId: UUID?
    var captureSource: String
    var deletedAt: Date?
    var keepForever: Bool
    var wasExportedToPhotos: Bool
    var exportedToPhotosAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        imageFilename: String,
        thumbnailFilename: String,
        note: String? = nil,
        expiresAt: Date,
        isArchived: Bool = false,
        folderId: UUID? = nil,
        captureSource: String = "camera",
        deletedAt: Date? = nil,
        keepForever: Bool = false,
        wasExportedToPhotos: Bool = false,
        exportedToPhotosAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
        self.note = note
        self.expiresAt = expiresAt
        self.isArchived = isArchived
        self.folderId = folderId
        self.captureSource = captureSource
        self.deletedAt = deletedAt
        self.keepForever = keepForever
        self.wasExportedToPhotos = wasExportedToPhotos
        self.exportedToPhotosAt = exportedToPhotosAt
    }
}

@Model
final class UserPreferences {
    var id: UUID
    // Stores the user-selected default expiration preset used by the capture flow.
    var defaultExpirationPreset: String
    // Tracks whether the app has already completed its one-time default folder setup.
    var hasCompletedInitialFolderSeed: Bool?
    // Kept for model compatibility with earlier builds; notifications are not user-configurable in v1.
    var notificationsEnabled: Bool
    // Kept for model compatibility with earlier builds; expired items are always auto-deleted in v1.
    var autoDeleteExpired: Bool
    var lastCleanupDate: Date?

    init(
        id: UUID = UUID(),
        defaultExpirationPreset: String = ExpirationPreset.sevenDays.rawValue,
        hasCompletedInitialFolderSeed: Bool? = nil,
        notificationsEnabled: Bool = false,
        autoDeleteExpired: Bool = true,
        lastCleanupDate: Date? = nil
    ) {
        self.id = id
        self.defaultExpirationPreset = defaultExpirationPreset
        self.hasCompletedInitialFolderSeed = hasCompletedInitialFolderSeed
        self.notificationsEnabled = notificationsEnabled
        self.autoDeleteExpired = autoDeleteExpired
        self.lastCleanupDate = lastCleanupDate
    }

    static func fetchOrCreate(in context: ModelContext) -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let preferences = UserPreferences()
        context.insert(preferences)
        try? context.save()
        return preferences
    }
}
