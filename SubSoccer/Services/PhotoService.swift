import Foundation
import UIKit
import CoreData
import Photos

class PhotoService: ObservableObject {
    static let shared = PhotoService()
    
    private init() {}
    
    // MARK: - Photo Processing
    
    func processImage(_ image: UIImage) -> (fullSize: Data?, thumbnail: Data?) {
        // Process full-size image
        let fullSizeData = compressImage(image, quality: 0.8, maxSize: CGSize(width: 1920, height: 1920))
        
        // Create thumbnail
        let thumbnailSize = CGSize(width: 200, height: 200)
        let thumbnail = createThumbnail(from: image, size: thumbnailSize)
        let thumbnailData = compressImage(thumbnail, quality: 0.7, maxSize: thumbnailSize)
        
        return (fullSizeData, thumbnailData)
    }
    
    private func compressImage(_ image: UIImage, quality: CGFloat, maxSize: CGSize) -> Data? {
        // Resize if needed
        let resizedImage = resizeImage(image, targetSize: maxSize)
        return resizedImage.jpegData(compressionQuality: quality)
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Only resize if the image is larger than target
        if scaleFactor >= 1.0 {
            return image
        }
        
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        }
    }
    
    private func createThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Core Data Operations
    
    func addPhoto(
        to session: TrainingSession,
        image: UIImage,
        caption: String? = nil,
        taggedPlayers: [Player] = [],
        in context: NSManagedObjectContext
    ) -> TrainingPhoto? {
        let processedImages = processImage(image)
        
        guard let imageData = processedImages.fullSize else {
            return nil
        }
        
        let photo = TrainingPhoto(context: context)
        photo.id = UUID()
        photo.imageData = imageData
        photo.thumbnailData = processedImages.thumbnail
        photo.caption = caption
        photo.createdAt = Date()
        photo.session = session
        
        // Add tagged players
        for player in taggedPlayers {
            photo.addToTaggedPlayers(player)
        }
        
        do {
            try context.save()
            return photo
        } catch {
            context.rollback()
            print("Failed to save photo: \(error)")
            return nil
        }
    }
    
    func deletePhoto(_ photo: TrainingPhoto, in context: NSManagedObjectContext) {
        context.delete(photo)
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to delete photo: \(error)")
        }
    }
    
    func updatePhotoCaption(_ photo: TrainingPhoto, caption: String, in context: NSManagedObjectContext) {
        photo.caption = caption
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to update photo caption: \(error)")
        }
    }
    
    func tagPlayers(_ players: [Player], in photo: TrainingPhoto, context: NSManagedObjectContext) {
        // Clear existing tags
        photo.removeFromTaggedPlayers(photo.taggedPlayers ?? NSSet())
        
        // Add new tags
        for player in players {
            photo.addToTaggedPlayers(player)
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to update player tags: \(error)")
        }
    }
    
    // MARK: - Photo Library Access
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        @unknown default:
            return false
        }
    }
    
    func saveToPhotoLibrary(_ image: UIImage) async -> Bool {
        guard await requestPhotoLibraryPermission() else {
            return false
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            print("Failed to save to photo library: \(error)")
            return false
        }
    }
    
    // MARK: - Image Utils
    
    func imageFromData(_ data: Data?) -> UIImage? {
        guard let data = data else { return nil }
        return UIImage(data: data)
    }
    
    func thumbnailFromPhoto(_ photo: TrainingPhoto) -> UIImage? {
        if let thumbnailData = photo.thumbnailData {
            return UIImage(data: thumbnailData)
        } else if let imageData = photo.imageData {
            // Generate thumbnail if it doesn't exist
            if let image = UIImage(data: imageData) {
                let thumbnail = createThumbnail(from: image, size: CGSize(width: 200, height: 200))
                return thumbnail
            }
        }
        return nil
    }
    
    func fullSizeImageFromPhoto(_ photo: TrainingPhoto) -> UIImage? {
        guard let imageData = photo.imageData else { return nil }
        return UIImage(data: imageData)
    }
}