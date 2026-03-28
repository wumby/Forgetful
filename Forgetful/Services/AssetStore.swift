import Foundation
import UIKit

struct SavedAsset {
    let imageFilename: String
    let thumbnailFilename: String
}

struct AssetStore {
    private let fileManager = FileManager.default

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

    func save(image: UIImage) throws -> SavedAsset {
        let baseName = UUID().uuidString.lowercased()
        let imageFilename = "\(baseName).jpg"
        let thumbnailFilename = "\(baseName)_thumb.jpg"

        guard let originalData = image.jpegData(compressionQuality: 0.9) else {
            throw AssetStoreError.encodingFailed
        }

        let thumbnail = image.preparingThumbnail(of: CGSize(width: 600, height: 600)) ?? image
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.75) else {
            throw AssetStoreError.encodingFailed
        }

        try originalData.write(to: originalsURL.appendingPathComponent(imageFilename), options: .atomic)
        try thumbnailData.write(to: thumbnailsURL.appendingPathComponent(thumbnailFilename), options: .atomic)

        return SavedAsset(imageFilename: imageFilename, thumbnailFilename: thumbnailFilename)
    }

    func loadOriginal(filename: String) -> UIImage? {
        UIImage(contentsOfFile: originalsURL.appendingPathComponent(filename).path)
    }

    func loadThumbnail(filename: String) -> UIImage? {
        UIImage(contentsOfFile: thumbnailsURL.appendingPathComponent(filename).path)
    }

    func deleteAssetFiles(imageFilename: String, thumbnailFilename: String) {
        try? fileManager.removeItem(at: originalsURL.appendingPathComponent(imageFilename))
        try? fileManager.removeItem(at: thumbnailsURL.appendingPathComponent(thumbnailFilename))
    }

    private func createDirectoryIfNeeded(_ url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

enum AssetStoreError: Error {
    case encodingFailed
}

