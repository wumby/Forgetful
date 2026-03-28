import Foundation
import SwiftData

enum ExpirationPreset: String, CaseIterable, Codable, Identifiable {
    case oneDay = "1d"
    case threeDays = "3d"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case never = "never"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneDay: "1 day"
        case .threeDays: "3 days"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .never: "Never"
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
    var defaultExpirationPreset: String
    var notificationsEnabled: Bool
    var autoDeleteExpired: Bool
    var lastCleanupDate: Date?

    init(
        id: UUID = UUID(),
        defaultExpirationPreset: String = ExpirationPreset.sevenDays.rawValue,
        notificationsEnabled: Bool = false,
        autoDeleteExpired: Bool = true,
        lastCleanupDate: Date? = nil
    ) {
        self.id = id
        self.defaultExpirationPreset = defaultExpirationPreset
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

enum SystemDestination: String, CaseIterable, Identifiable {
    case all
    case expiringSoon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .expiringSoon: "Expiring Soon"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.stack"
        case .expiringSoon: "clock.badge.exclamationmark"
        }
    }
}
