import Foundation
import CoreData

class InjuryManagementService: ObservableObject {
    static let shared = InjuryManagementService()
    
    private init() {}
    
    // MARK: - Injury Management
    
    func markPlayerAsInjured(
        player: Player,
        description: String,
        injuryDate: Date = Date(),
        expectedReturnDate: Date? = nil,
        in context: NSManagedObjectContext
    ) {
        player.isInjured = true
        player.injuryDescription = description
        player.injuryDate = injuryDate
        player.returnToPlayDate = expectedReturnDate
        player.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to mark player as injured: \(error)")
        }
    }
    
    func markPlayerAsRecovered(
        player: Player,
        in context: NSManagedObjectContext
    ) {
        player.isInjured = false
        player.injuryDescription = nil
        player.injuryDate = nil
        player.returnToPlayDate = nil
        player.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to mark player as recovered: \(error)")
        }
    }
    
    func updateInjuryDetails(
        player: Player,
        description: String? = nil,
        expectedReturnDate: Date? = nil,
        in context: NSManagedObjectContext
    ) {
        if let description = description {
            player.injuryDescription = description
        }
        
        player.returnToPlayDate = expectedReturnDate
        player.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to update injury details: \(error)")
        }
    }
    
    // MARK: - Injury Status Checks
    
    func isPlayerAvailable(_ player: Player) -> Bool {
        return !player.isInjured
    }
    
    func getInjuredPlayers(from team: Team) -> [Player] {
        let players = (team.players as? Set<Player>) ?? []
        return players.filter { $0.isInjured }.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        }
    }
    
    func getAvailablePlayers(from team: Team) -> [Player] {
        let players = (team.players as? Set<Player>) ?? []
        return players.filter { !$0.isInjured }.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        }
    }
    
    func getPlayersReturningThisWeek(from team: Team) -> [Player] {
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let players = (team.players as? Set<Player>) ?? []
        
        return players.filter { player in
            guard player.isInjured,
                  let returnDate = player.returnToPlayDate else {
                return false
            }
            return returnDate <= endOfWeek && returnDate >= Date()
        }.sorted { 
            ($0.returnToPlayDate ?? Date.distantFuture) < ($1.returnToPlayDate ?? Date.distantFuture)
        }
    }
    
    func getOverdueReturns(from team: Team) -> [Player] {
        let today = Date()
        let players = (team.players as? Set<Player>) ?? []
        
        return players.filter { player in
            guard player.isInjured,
                  let returnDate = player.returnToPlayDate else {
                return false
            }
            return returnDate < today
        }.sorted { 
            ($0.returnToPlayDate ?? Date.distantPast) < ($1.returnToPlayDate ?? Date.distantPast)
        }
    }
    
    // MARK: - Injury Statistics
    
    func getInjuryStatistics(for team: Team) -> InjuryStatistics {
        let players = (team.players as? Set<Player>) ?? []
        let totalPlayers = players.count
        let injuredPlayers = players.filter { $0.isInjured }.count
        let availablePlayers = totalPlayers - injuredPlayers
        
        let currentInjuries = players.filter { $0.isInjured }
        let averageInjuryDuration = calculateAverageInjuryDuration(for: Array(currentInjuries))
        
        return InjuryStatistics(
            totalPlayers: totalPlayers,
            availablePlayers: availablePlayers,
            injuredPlayers: injuredPlayers,
            injuryRate: totalPlayers > 0 ? Double(injuredPlayers) / Double(totalPlayers) : 0.0,
            averageInjuryDuration: averageInjuryDuration
        )
    }
    
    private func calculateAverageInjuryDuration(for injuredPlayers: [Player]) -> Int {
        guard !injuredPlayers.isEmpty else { return 0 }
        
        let totalDays = injuredPlayers.compactMap { player in
            guard let injuryDate = player.injuryDate else { return nil }
            return Calendar.current.dateComponents([.day], from: injuryDate, to: Date()).day
        }.reduce(0, +)
        
        return totalDays / injuredPlayers.count
    }
    
    // MARK: - Lineup Filtering
    
    func filterAvailablePlayersForLineup(_ players: [Player]) -> [Player] {
        return players.filter { isPlayerAvailable($0) }
    }
    
    func getAlternativePlayersForPosition(_ position: String, from team: Team, excluding: [Player] = []) -> [Player] {
        let availablePlayers = getAvailablePlayers(from: team)
        let excludedIds = Set(excluding.compactMap { $0.id })
        
        return availablePlayers.filter { player in
            guard let playerId = player.id, !excludedIds.contains(playerId) else { return false }
            return player.position == position
        }
    }
    
    // MARK: - Notifications & Reminders
    
    func getReturnToPlayReminders(for team: Team, daysAhead: Int = 3) -> [ReturnToPlayReminder] {
        let targetDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        let players = (team.players as? Set<Player>) ?? []
        
        return players.compactMap { player in
            guard player.isInjured,
                  let returnDate = player.returnToPlayDate,
                  Calendar.current.isDate(returnDate, inSameDayAs: targetDate) else {
                return nil
            }
            
            return ReturnToPlayReminder(
                player: player,
                returnDate: returnDate,
                daysUntilReturn: daysAhead
            )
        }
    }
}

// MARK: - Data Models

struct InjuryStatistics {
    let totalPlayers: Int
    let availablePlayers: Int
    let injuredPlayers: Int
    let injuryRate: Double // 0.0 to 1.0
    let averageInjuryDuration: Int // in days
}

struct ReturnToPlayReminder {
    let player: Player
    let returnDate: Date
    let daysUntilReturn: Int
}

enum InjuryType: String, CaseIterable {
    case muscle = "Muscle Strain"
    case ligament = "Ligament Injury"
    case bone = "Bone Injury"
    case joint = "Joint Injury"
    case head = "Head Injury"
    case other = "Other"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .muscle:
            return "figure.run"
        case .ligament:
            return "bandage"
        case .bone:
            return "xmark.shield"
        case .joint:
            return "figure.walk"
        case .head:
            return "brain.head.profile"
        case .other:
            return "medical.bag"
        }
    }
}

enum InjurySeverity: String, CaseIterable {
    case minor = "Minor"
    case moderate = "Moderate"
    case major = "Major"
    
    var displayName: String {
        return rawValue
    }
    
    var color: String {
        switch self {
        case .minor:
            return "yellow"
        case .moderate:
            return "orange"
        case .major:
            return "red"
        }
    }
    
    var estimatedRecoveryDays: Int {
        switch self {
        case .minor:
            return 7
        case .moderate:
            return 21
        case .major:
            return 60
        }
    }
}