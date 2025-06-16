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
    
    func addRosieFCWithPlayers() {
        let viewContext = container.viewContext
        
        // Create Rosie FC team
        let rosieFCTeam = Team(context: viewContext)
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
        
        // Create players
        for playerInfo in playerData {
            let player = Player(context: viewContext)
            player.id = UUID()
            player.name = playerInfo.name
            player.position = playerInfo.position
            player.jerseyNumber = playerInfo.jerseyNumber
            player.team = rosieFCTeam
        }
        
        do {
            try viewContext.save()
            print("Successfully added Rosie FC with 20 players")
        } catch {
            let nsError = error as NSError
            print("Failed to add Rosie FC: \(nsError), \(nsError.userInfo)")
        }
    }
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SubSoccer")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}