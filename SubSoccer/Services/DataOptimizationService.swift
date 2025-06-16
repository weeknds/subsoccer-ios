import Foundation
import CoreData
import UIKit

/// Service for managing data efficiently with lazy loading and caching
@MainActor
class DataOptimizationService: ObservableObject {
    static let shared = DataOptimizationService()
    
    private let persistenceController = PersistenceController.shared
    private var imageCache = NSCache<NSString, UIImage>()
    private var thumbnailCache = NSCache<NSString, UIImage>()
    
    // MARK: - Image Optimization
    
    init() {
        configureImageCaches()
    }
    
    private func configureImageCaches() {
        imageCache.countLimit = 50 // Limit to 50 images
        imageCache.totalCostLimit = 100 * 1024 * 1024 // 100MB limit
        
        thumbnailCache.countLimit = 200 // More thumbnails
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        // Clear caches on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearImageCaches()
            }
        }
    }
    
    @MainActor
    func clearImageCaches() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
    
    /// Optimized image loading with compression and caching
    func loadOptimizedImage(from data: Data, cacheKey: String, targetSize: CGSize? = nil) -> UIImage? {
        // Check cache first
        if let targetSize = targetSize {
            let thumbnailKey = "\(cacheKey)_\(Int(targetSize.width))x\(Int(targetSize.height))"
            if let cachedThumbnail = thumbnailCache.object(forKey: thumbnailKey as NSString) {
                return cachedThumbnail
            }
        } else {
            if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
                return cachedImage
            }
        }
        
        // Load and process image
        guard let image = UIImage(data: data) else { return nil }
        
        let processedImage: UIImage
        if let targetSize = targetSize {
            processedImage = image.resized(to: targetSize) ?? image
            let thumbnailKey = "\(cacheKey)_\(Int(targetSize.width))x\(Int(targetSize.height))"
            thumbnailCache.setObject(processedImage, forKey: thumbnailKey as NSString)
        } else {
            processedImage = image.compressed() ?? image
            imageCache.setObject(processedImage, forKey: cacheKey as NSString)
        }
        
        return processedImage
    }
    
    /// Compress image data for storage
    func compressImageData(_ data: Data, maxSizeKB: Int = 500) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        var compressionQuality: CGFloat = 1.0
        var compressedData = data
        let maxSize = maxSizeKB * 1024
        
        // Reduce quality until size is acceptable
        while compressedData.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            if let newData = image.jpegData(compressionQuality: compressionQuality) {
                compressedData = newData
            }
        }
        
        return compressedData
    }
    
    // MARK: - Lazy Loading Support
    
    /// Paginated fetch for large datasets
    func fetchPaginatedPlayers(
        for team: Team,
        searchText: String = "",
        offset: Int = 0,
        limit: Int = 20
    ) async -> [Player] {
        return await withCheckedContinuation { continuation in
            let context = self.persistenceController.container.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<Player> = Player.fetchRequest()
                
                var predicates: [NSPredicate] = [NSPredicate(format: "team == %@", team)]
                
                if !searchText.isEmpty {
                    let searchPredicate = NSPredicate(
                        format: "name CONTAINS[cd] %@ OR position CONTAINS[cd] %@ OR jerseyNumber == %d",
                        searchText, searchText, Int16(searchText) ?? 0
                    )
                    predicates.append(searchPredicate)
                }
                
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Player.jerseyNumber, ascending: true)]
                request.fetchOffset = offset
                request.fetchLimit = limit
                request.fetchBatchSize = limit
                request.returnsObjectsAsFaults = false
                
                do {
                    let players = try context.fetch(request)
                    continuation.resume(returning: players)
                } catch {
                    print("Error fetching paginated players: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Efficient count query
    func countPlayers(for team: Team, searchText: String = "") async -> Int {
        return await withCheckedContinuation { continuation in
            let context = self.persistenceController.container.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<Player> = Player.fetchRequest()
                
                var predicates: [NSPredicate] = [NSPredicate(format: "team == %@", team)]
                
                if !searchText.isEmpty {
                    let searchPredicate = NSPredicate(
                        format: "name CONTAINS[cd] %@ OR position CONTAINS[cd] %@ OR jerseyNumber == %d",
                        searchText, searchText, Int16(searchText) ?? 0
                    )
                    predicates.append(searchPredicate)
                }
                
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                
                do {
                    let count = try context.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    print("Error counting players: \(error)")
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    // MARK: - Background Data Operations
    
    /// Batch update player data
    func batchUpdatePlayers(_ updates: [(Player, [String: Any])]) async throws {
        try await persistenceController.performBackgroundTask { context in
            for (player, updates) in updates {
                guard let objectID = player.objectID.uriRepresentation().absoluteString.data(using: .utf8),
                      let uri = URL(string: String(data: objectID, encoding: .utf8) ?? ""),
                      let managedObjectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri),
                      let contextPlayer = try context.existingObject(with: managedObjectID) as? Player else {
                    continue
                }
                
                for (key, value) in updates {
                    contextPlayer.setValue(value, forKey: key)
                }
            }
            
            try context.save()
        }
    }
    
    /// Preload related data for better performance
    func preloadPlayerStatistics(for players: [Player]) async {
        await withTaskGroup(of: Void.self) { group in
            for player in players {
                group.addTask {
                    await self.preloadStatistics(for: player)
                }
            }
        }
    }
    
    private func preloadStatistics(for player: Player) async {
        _ = await withCheckedContinuation { continuation in
            let context = self.persistenceController.container.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<PlayerStats> = PlayerStats.fetchRequest()
                request.predicate = NSPredicate(format: "player == %@", player)
                request.fetchBatchSize = 20
                request.returnsObjectsAsFaults = false
                
                do {
                    _ = try context.fetch(request)
                    continuation.resume(returning: ())
                } catch {
                    print("Error preloading statistics: \(error)")
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Resize image to target size while maintaining aspect ratio
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Compress image while maintaining quality
    func compressed(quality: CGFloat = 0.8) -> UIImage? {
        guard let data = self.jpegData(compressionQuality: quality),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}