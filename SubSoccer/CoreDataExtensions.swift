import Foundation
import CoreData

// MARK: - Core Data Extensions

extension Match {
    var playerStatsArray: [PlayerStats] {
        let set = playerStats as? Set<PlayerStats> ?? []
        return set.sorted { $0.player?.name ?? "" < $1.player?.name ?? "" }
    }
}

extension Player {
    var statisticsArray: [PlayerStats] {
        let set = statistics as? Set<PlayerStats> ?? []
        return set.sorted { $0.match?.date ?? Date() > $1.match?.date ?? Date() }
    }
}

extension Team {
    var playersArray: [Player] {
        let set = players as? Set<Player> ?? []
        return set.sorted { $0.name ?? "" < $1.name ?? "" }
    }
}