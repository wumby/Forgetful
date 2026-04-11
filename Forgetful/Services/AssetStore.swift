import Foundation
import ImageIO
import UIKit

struct SavedAsset {
    let imageFilename: String
    let thumbnailFilename: String
}

@MainActor
struct AssetStore {
    private let fileManager = FileManager.default
    private static let thumbnailCache = NSCache<NSString, UIImage>()
    private static let displayCache = NSCache<NSString, UIImage>()

    private static let displayImageMaxPixelSize: CGFloat = 1800
    private static let storedImageMaxDimension: CGFloat = 2400
    private static let thumbnailMaxPixelSize: CGFloat = 600

    init() {
        Self.thumbnailCache.countLimit = 200
        Self.displayCache.countLimit = 12
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

        let preparedAssets = try prepareAssetsForStorage(from: image)
        let originalData = preparedAssets.originalData
        let thumbnail = preparedAssets.thumbnail
        let thumbnailData = preparedAssets.thumbnailData

        do {
            try originalData.write(to: originalURL, options: .atomic)
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: originalURL)
            try? fileManager.removeItem(at: thumbnailURL)
            throw error
        }

        Self.thumbnailCache.setObject(thumbnail, forKey: thumbnailFilename as NSString)
        Self.displayCache.removeAllObjects()

        return SavedAsset(imageFilename: imageFilename, thumbnailFilename: thumbnailFilename)
    }

    func loadOriginal(filename: String) -> UIImage? {
        UIImage(contentsOfFile: originalsURL.appendingPathComponent(filename).path)
    }

    func loadDisplayImage(filename: String, maxPixelSize: CGFloat = AssetStore.displayImageMaxPixelSize) -> UIImage? {
        let cacheKey = "\(filename)-\(Int(maxPixelSize.rounded()))" as NSString
        if let cached = Self.displayCache.object(forKey: cacheKey) {
            return cached
        }

        let imageURL = originalsURL.appendingPathComponent(filename)
        guard let image = downsampledImage(at: imageURL, maxPixelSize: maxPixelSize) else {
            return loadOriginal(filename: filename)
        }

        Self.displayCache.setObject(image, forKey: cacheKey)
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
        Self.thumbnailCache.removeObject(forKey: thumbnailFilename as NSString)
        Self.displayCache.removeAllObjects()
        try? fileManager.removeItem(at: originalsURL.appendingPathComponent(imageFilename))
        try? fileManager.removeItem(at: thumbnailsURL.appendingPathComponent(thumbnailFilename))
    }

    private func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded()))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func prepareAssetsForStorage(from image: UIImage) throws -> (originalData: Data, thumbnail: UIImage, thumbnailData: Data) {
        let storageImage = resizedImageIfNeeded(image, maxDimension: Self.storedImageMaxDimension) ?? image

        guard let originalData = storageImage.jpegData(compressionQuality: 0.88) else {
            throw AssetStoreError.encodingFailed
        }

        let thumbnail = storageImage.preparingThumbnail(
            of: CGSize(width: Self.thumbnailMaxPixelSize, height: Self.thumbnailMaxPixelSize)
        ) ?? storageImage

        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.75) else {
            throw AssetStoreError.encodingFailed
        }

        return (originalData, thumbnail, thumbnailData)
    }

    private func resizedImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else {
            return nil
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(
            width: max(1, (size.width * scale).rounded(.toNearestOrAwayFromZero)),
            height: max(1, (size.height * scale).rounded(.toNearestOrAwayFromZero))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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
