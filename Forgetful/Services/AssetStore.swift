import Foundation
import UIKit

struct SavedAsset {
    let imageFilename: String
    let thumbnailFilename: String
}

@MainActor
struct AssetStore {
    private let fileManager = FileManager.default
    private static let thumbnailCache = NSCache<NSString, UIImage>()
    private static let originalCache = NSCache<NSString, UIImage>()

    init() {
        Self.thumbnailCache.countLimit = 200
        Self.originalCache.countLimit = 24
    }

    private var baseURL: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = applicationSupport.appendingPathComponent("Forgetful", isDirectory: true)
        createDirectoryIfNeeded(url)
        return url
    }

    private var originalsURL: URL {
        let url = baseURL.appendingPathComponent("Originals", isDirectory: true)
        createDirectoryIfNeeded(url)
        return url
    }

    private var thumbnailsURL: URL {
        let url = baseURL.appendingPathComponent("Thumbnails", isDirectory: true)
        createDirectoryIfNeeded(url)
        return url
    }

    func originalFileURL(filename: String) -> URL {
        originalsURL.appendingPathComponent(filename)
    }

    func save(image: UIImage) throws -> SavedAsset {
        let baseName = UUID().uuidString.lowercased()
        let imageFilename = "\(baseName).jpg"
        let thumbnailFilename = "\(baseName)_thumb.jpg"
        let originalURL = originalsURL.appendingPathComponent(imageFilename)
        let thumbnailURL = thumbnailsURL.appendingPathComponent(thumbnailFilename)

        guard let originalData = image.jpegData(compressionQuality: 0.9) else {
            throw AssetStoreError.encodingFailed
        }

        let thumbnail = image.preparingThumbnail(of: CGSize(width: 600, height: 600)) ?? image
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.75) else {
            throw AssetStoreError.encodingFailed
        }

        do {
            try originalData.write(to: originalURL, options: .atomic)
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: originalURL)
            try? fileManager.removeItem(at: thumbnailURL)
            throw error
        }

        Self.originalCache.setObject(image, forKey: imageFilename as NSString)
        Self.thumbnailCache.setObject(thumbnail, forKey: thumbnailFilename as NSString)

        return SavedAsset(imageFilename: imageFilename, thumbnailFilename: thumbnailFilename)
    }

    func loadOriginal(filename: String) -> UIImage? {
        let key = filename as NSString
        if let cached = Self.originalCache.object(forKey: key) {
            return cached
        }

        let image = UIImage(contentsOfFile: originalsURL.appendingPathComponent(filename).path)
        if let image {
            Self.originalCache.setObject(image, forKey: key)
        }
        return image
    }

    func loadThumbnail(filename: String) -> UIImage? {
        let key = filename as NSString
        if let cached = Self.thumbnailCache.object(forKey: key) {
            return cached
        }

        let image = UIImage(contentsOfFile: thumbnailsURL.appendingPathComponent(filename).path)
        if let image {
            Self.thumbnailCache.setObject(image, forKey: key)
        }
        return image
    }

    func deleteAssetFiles(imageFilename: String, thumbnailFilename: String) {
        Self.originalCache.removeObject(forKey: imageFilename as NSString)
        Self.thumbnailCache.removeObject(forKey: thumbnailFilename as NSString)
        try? fileManager.removeItem(at: originalsURL.appendingPathComponent(imageFilename))
        try? fileManager.removeItem(at: thumbnailsURL.appendingPathComponent(thumbnailFilename))
    }

    private func createDirectoryIfNeeded(_ url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

enum AssetStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "This photo couldn't be prepared for saving."
        }
    }
}
