import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Extensions

extension Match {
    var playerStatsArray: [PlayerStats] {
        let set = playerStats as? Set<PlayerStats> ?? []
        return set.sorted { $0.player?.name ?? "" < $1.player?.name ?? "" }
    }
    
    /// Optimized fetch for player stats with predicates
    static func fetchMatches(for team: Team, in context: NSManagedObjectContext, limit: Int? = nil) -> [Match] {
        let request: NSFetchRequest<Match> = Match.fetchRequest()
        request.predicate = NSPredicate(format: "team == %@", team)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Match.date, ascending: false)]
        request.fetchBatchSize = 20
        request.returnsObjectsAsFaults = false
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching matches: \(error)")
            return []
        }
    }
}

extension Player {
    var statisticsArray: [PlayerStats] {
        let set = statistics as? Set<PlayerStats> ?? []
        return set.sorted { $0.match?.date ?? Date() > $1.match?.date ?? Date() }
    }
    
    /// Optimized fetch for active (non-injured) players
    static func fetchActivePlayers(for team: Team, in context: NSManagedObjectContext) -> [Player] {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "team == %@ AND (isInjured == NO OR isInjured == nil)", team)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Player.jerseyNumber, ascending: true)]
        request.fetchBatchSize = 25
        request.returnsObjectsAsFaults = false
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching active players: \(error)")
            return []
        }
    }
    
    /// Get player statistics for a specific timeframe
    func getStatistics(timeframe: StatisticsTimeframe, in context: NSManagedObjectContext) -> [PlayerStats] {
        let request: NSFetchRequest<PlayerStats> = PlayerStats.fetchRequest()
        
        var predicates: [NSPredicate] = [NSPredicate(format: "player == %@", self)]
        
        switch timeframe {
        case .lastWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            predicates.append(NSPredicate(format: "match.date >= %@", oneWeekAgo as NSDate))
        case .lastMonth:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            predicates.append(NSPredicate(format: "match.date >= %@", oneMonthAgo as NSDate))
        case .allTime:
            break
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerStats.match?.date, ascending: false)]
        request.fetchBatchSize = 20
        request.returnsObjectsAsFaults = false
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching player statistics: \(error)")
            return []
        }
    }
}

extension Team {
    var playersArray: [Player] {
        let set = players as? Set<Player> ?? []
        return set.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    /// Optimized fetch for team players with search
    func searchPlayers(searchText: String, in context: NSManagedObjectContext) -> [Player] {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        
        var predicates: [NSPredicate] = [NSPredicate(format: "team == %@", self)]
        
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "name CONTAINS[cd] %@ OR position CONTAINS[cd] %@ OR jerseyNumber == %d", 
                                            searchText, searchText, Int16(searchText) ?? 0)
            predicates.append(searchPredicate)
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Player.jerseyNumber, ascending: true)]
        request.fetchBatchSize = 25
        request.returnsObjectsAsFaults = false
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error searching players: \(error)")
            return []
        }
    }
    
    /// Get team statistics summary
    func getTeamStatsSummary(timeframe: StatisticsTimeframe, in context: NSManagedObjectContext) -> TeamStatsSummary {
        let request: NSFetchRequest<PlayerStats> = PlayerStats.fetchRequest()
        
        var predicates: [NSPredicate] = [NSPredicate(format: "player.team == %@", self)]
        
        switch timeframe {
        case .lastWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            predicates.append(NSPredicate(format: "match.date >= %@", oneWeekAgo as NSDate))
        case .lastMonth:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            predicates.append(NSPredicate(format: "match.date >= %@", oneMonthAgo as NSDate))
        case .allTime:
            break
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchBatchSize = 100
        
        do {
            let stats = try context.fetch(request)
            
            let totalGoals = stats.reduce(0) { $0 + Int($1.goals) }
            let totalAssists = stats.reduce(0) { $0 + Int($1.assists) }
            let totalMinutes = stats.reduce(0) { $0 + Int($1.minutesPlayed) }
            let matchesPlayed = Set(stats.compactMap { $0.match }).count
            
            return TeamStatsSummary(
                totalGoals: totalGoals,
                totalAssists: totalAssists,
                totalMinutes: totalMinutes,
                matchesPlayed: matchesPlayed,
                playersCount: playersArray.count
            )
        } catch {
            print("Error fetching team stats: \(error)")
            return TeamStatsSummary(totalGoals: 0, totalAssists: 0, totalMinutes: 0, matchesPlayed: 0, playersCount: 0)
        }
    }
}

// MARK: - Supporting Types

struct TeamStatsSummary {
    let totalGoals: Int
    let totalAssists: Int
    let totalMinutes: Int
    let matchesPlayed: Int
    let playersCount: Int
}