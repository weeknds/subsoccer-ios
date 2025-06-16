import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleTeam = Team(context: viewContext)
        sampleTeam.id = UUID()
        sampleTeam.name = "Sample Team"
        sampleTeam.createdAt = Date()
        
        let samplePlayer = Player(context: viewContext)
        samplePlayer.id = UUID()
        samplePlayer.name = "John Doe"
        samplePlayer.jerseyNumber = 10
        samplePlayer.position = "MID"
        samplePlayer.team = sampleTeam
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    // Background context for heavy operations
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    func addRosieFCWithPlayers() {
        Task {
            do {
                try await performBackgroundTask { context in
                    // Create Rosie FC team
                    let rosieFCTeam = Team(context: context)
                    rosieFCTeam.id = UUID()
                    rosieFCTeam.name = "Rosie FC"
                    rosieFCTeam.createdAt = Date()
                    
                    // Sample player names and positions
                    let playerData: [(name: String, position: String, jerseyNumber: Int16)] = [
                        ("Emma Rodriguez", "GK", 1),
                        ("Sofia Martinez", "CB", 2),
                        ("Isabella Thompson", "CB", 3),
                        ("Mia Johnson", "LB", 4),
                        ("Charlotte Williams", "RB", 5),
                        ("Amelia Brown", "CM", 6),
                        ("Harper Davis", "CM", 7),
                        ("Evelyn Miller", "LM", 8),
                        ("Abigail Wilson", "RM", 9),
                        ("Emily Moore", "CF", 10),
                        ("Elizabeth Taylor", "LF", 11),
                        ("Mila Anderson", "RF", 12),
                        ("Ella Thomas", "GK", 13),
                        ("Avery Jackson", "CB", 14),
                        ("Sofia White", "LB", 15),
                        ("Camila Harris", "CM", 16),
                        ("Aria Martin", "RM", 17),
                        ("Scarlett Garcia", "CF", 18),
                        ("Victoria Clark", "LF", 19),
                        ("Madison Lewis", "RF", 20)
                    ]
                    
                    // Create players in batch for better performance
                    for playerInfo in playerData {
                        let player = Player(context: context)
                        player.id = UUID()
                        player.name = playerInfo.name
                        player.position = playerInfo.position
                        player.jerseyNumber = playerInfo.jerseyNumber
                        player.team = rosieFCTeam
                    }
                    
                    try context.save()
                    print("Successfully added Rosie FC with 20 players")
                }
            } catch {
                let nsError = error as NSError
                print("Failed to add Rosie FC: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SubSoccer")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Performance optimizations for persistent store
            let description = container.persistentStoreDescriptions.first!
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            
            // Enable persistent store remote change notifications
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Optimize view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up efficient batch operations
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }
    
    // MARK: - Performance Helper Methods
    
    /// Performs a batch operation in a background context
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let context = container.newBackgroundContext()
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Optimized batch delete for entities
    func batchDelete<T: NSManagedObject>(entityType: T.Type, predicate: NSPredicate? = nil) async throws {
        try await performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
            if let predicate = predicate {
                fetchRequest.predicate = predicate
            }
            
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSDeletedObjectsKey: objectIDArray]
            
            // Merge changes to view context
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.container.viewContext])
        }
    }
    
    /// Optimized count query
    func count<T: NSManagedObject>(for entityType: T.Type, predicate: NSPredicate? = nil) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let context = container.newBackgroundContext()
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entityType))
                    fetchRequest.predicate = predicate
                    let count = try context.count(for: fetchRequest)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}