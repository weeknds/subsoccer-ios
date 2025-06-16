import Foundation
import CoreData

class LineupSuggestionService: ObservableObject {
    static let shared = LineupSuggestionService()
    
    private init() {}
    
    // MARK: - Balanced Playtime Algorithm
    
    func generateBalancedLineup(
        for team: Team,
        playersOnField: Int = 11,
        considerPlaytime: Bool = true,
        considerPerformance: Bool = false,
        formation: Formation = .fourFourTwo
    ) -> LineupSuggestion {
        let players = (team.players as? Set<Player>)?.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        } ?? []
        
        let availablePlayers = players.filter { !isInjured($0) }
        
        if availablePlayers.count < playersOnField {
            return LineupSuggestion(
                formation: formation,
                lineup: [],
                bench: availablePlayers,
                reasoning: "Not enough available players for full lineup",
                balanceScore: 0.0
            )
        }
        
        var playerScores: [(Player, Double)] = []
        
        for player in availablePlayers {
            let score = calculatePlayerScore(
                player: player,
                considerPlaytime: considerPlaytime,
                considerPerformance: considerPerformance
            )
            playerScores.append((player, score))
        }
        
        // Sort by score (higher score = higher priority for playing)
        playerScores.sort { $0.1 > $1.1 }
        
        let lineup = assignPositions(
            playerScores: playerScores,
            formation: formation,
            playersOnField: playersOnField
        )
        
        let selectedPlayers = Set(lineup.map { $0.player })
        let bench = availablePlayers.filter { !selectedPlayers.contains($0) }
        
        let balanceScore = calculateBalanceScore(lineup: lineup)
        let reasoning = generateReasoning(
            lineup: lineup,
            formation: formation,
            considerPlaytime: considerPlaytime,
            considerPerformance: considerPerformance
        )
        
        return LineupSuggestion(
            formation: formation,
            lineup: lineup,
            bench: bench,
            reasoning: reasoning,
            balanceScore: balanceScore
        )
    }
    
    private func calculatePlayerScore(
        player: Player,
        considerPlaytime: Bool,
        considerPerformance: Bool
    ) -> Double {
        var score: Double = 0.0
        
        // Base availability score
        score += 10.0
        
        if considerPlaytime {
            let playtimeScore = calculatePlaytimeScore(player: player)
            score += playtimeScore * 0.6 // 60% weight for playtime balance
        }
        
        if considerPerformance {
            let performanceScore = calculatePerformanceScore(player: player)
            score += performanceScore * 0.4 // 40% weight for performance
        }
        
        // Position preference bonus
        let positionScore = getPositionPreferenceScore(player: player)
        score += positionScore * 0.2
        
        return score
    }
    
    private func calculatePlaytimeScore(player: Player) -> Double {
        let stats = player.statistics as? Set<PlayerStats> ?? []
        let totalMinutes = stats.reduce(0) { $0 + Int($1.minutesPlayed) }
        let recentMatches = stats.filter { 
            guard let match = $0.match, let date = match.date else { return false }
            return date > Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        }
        let recentMinutes = recentMatches.reduce(0) { $0 + Int($1.minutesPlayed) }
        
        // Players with less recent playtime get higher priority
        let avgMinutesPerMatch = recentMatches.isEmpty ? 0 : recentMinutes / recentMatches.count
        let maxExpectedMinutes = 90 // Full match duration
        
        // Inverse score - less playtime = higher priority
        return Double(maxExpectedMinutes - avgMinutesPerMatch) / Double(maxExpectedMinutes) * 10.0
    }
    
    private func calculatePerformanceScore(player: Player) -> Double {
        let stats = player.statistics as? Set<PlayerStats> ?? []
        let recentStats = stats.filter { 
            guard let match = $0.match, let date = match.date else { return false }
            return date > Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }
        
        if recentStats.isEmpty { return 5.0 } // Neutral score for no recent performance
        
        let totalGoals = recentStats.reduce(0) { $0 + Int($1.goals) }
        let totalAssists = recentStats.reduce(0) { $0 + Int($1.assists) }
        let totalMinutes = recentStats.reduce(0) { $0 + Int($1.minutesPlayed) }
        
        let goalsPerMinute = totalMinutes > 0 ? Double(totalGoals) / Double(totalMinutes) * 90 : 0
        let assistsPerMinute = totalMinutes > 0 ? Double(totalAssists) / Double(totalMinutes) * 90 : 0
        
        return (goalsPerMinute * 3 + assistsPerMinute * 2) // Goals weighted more than assists
    }
    
    private func getPositionPreferenceScore(player: Player) -> Double {
        // Simple position preference - could be enhanced with player preferences
        guard let position = player.position else { return 0.0 }
        
        switch position {
        case "GK": return 2.0 // Goalkeepers are specialized
        case "DEF": return 1.5
        case "MID": return 1.0
        case "FWD": return 1.2
        default: return 0.5
        }
    }
    
    private func assignPositions(
        playerScores: [(Player, Double)],
        formation: Formation,
        playersOnField: Int
    ) -> [LineupPlayerPosition] {
        var lineup: [LineupPlayerPosition] = []
        var usedPlayers: Set<Player> = []
        
        let positionRequirements = formation.positionRequirements
        
        // First, assign specialized positions (GK)
        if let goalkeeper = playerScores.first(where: { $0.0.position == "GK" && !usedPlayers.contains($0.0) }) {
            lineup.append(LineupPlayerPosition(player: goalkeeper.0, position: .goalkeeper, x: 0.5, y: 0.1))
            usedPlayers.insert(goalkeeper.0)
        }
        
        // Assign defenders
        let defenders = playerScores.filter { $0.0.position == "DEF" && !usedPlayers.contains($0.0) }
        let defenderPositions = formation.getDefenderPositions()
        for (index, defenderPos) in defenderPositions.enumerated() {
            if index < defenders.count {
                lineup.append(LineupPlayerPosition(player: defenders[index].0, position: .defender, x: defenderPos.x, y: defenderPos.y))
                usedPlayers.insert(defenders[index].0)
            }
        }
        
        // Assign midfielders
        let midfielders = playerScores.filter { $0.0.position == "MID" && !usedPlayers.contains($0.0) }
        let midfielderPositions = formation.getMidfielderPositions()
        for (index, midPos) in midfielderPositions.enumerated() {
            if index < midfielders.count {
                lineup.append(LineupPlayerPosition(player: midfielders[index].0, position: .midfielder, x: midPos.x, y: midPos.y))
                usedPlayers.insert(midfielders[index].0)
            }
        }
        
        // Assign forwards
        let forwards = playerScores.filter { $0.0.position == "FWD" && !usedPlayers.contains($0.0) }
        let forwardPositions = formation.getForwardPositions()
        for (index, fwdPos) in forwardPositions.enumerated() {
            if index < forwards.count {
                lineup.append(LineupPlayerPosition(player: forwards[index].0, position: .forward, x: fwdPos.x, y: fwdPos.y))
                usedPlayers.insert(forwards[index].0)
            }
        }
        
        // Fill remaining positions with best available players
        let remainingPlayers = playerScores.filter { !usedPlayers.contains($0.0) }
        let remainingPositionsNeeded = playersOnField - lineup.count
        
        for i in 0..<min(remainingPositionsNeeded, remainingPlayers.count) {
            let player = remainingPlayers[i].0
            let position = determineOptimalPosition(for: player, in: formation, usedPositions: lineup)
            lineup.append(position)
            usedPlayers.insert(player)
        }
        
        return lineup
    }
    
    private func determineOptimalPosition(for player: Player, in formation: Formation, usedPositions: [LineupPlayerPosition]) -> LineupPlayerPosition {
        // Simple position assignment based on available spots
        let usedCoordinates = Set(usedPositions.map { "\($0.x)-\($0.y)" })
        
        let allPositions = formation.getAllPositions()
        for pos in allPositions {
            let key = "\(pos.x)-\(pos.y)"
            if !usedCoordinates.contains(key) {
                return LineupPlayerPosition(player: player, position: pos.position, x: pos.x, y: pos.y)
            }
        }
        
        // Fallback to midfield
        return LineupPlayerPosition(player: player, position: .midfielder, x: 0.5, y: 0.5)
    }
    
    private func calculateBalanceScore(lineup: [LineupPlayerPosition]) -> Double {
        // Calculate how balanced the lineup is based on various factors
        var score: Double = 10.0
        
        // Position distribution score
        let positionCounts = lineup.reduce(into: [LineupFieldPosition: Int]()) { counts, playerPos in
            counts[playerPos.position, default: 0] += 1
        }
        
        // Penalize for missing key positions
        if positionCounts[.goalkeeper] == 0 { score -= 3.0 }
        if positionCounts[.defender] ?? 0 < 2 { score -= 2.0 }
        if positionCounts[.midfielder] ?? 0 < 2 { score -= 1.0 }
        if positionCounts[.forward] ?? 0 < 1 { score -= 1.0 }
        
        // Playtime balance score
        let players = lineup.map { $0.player }
        let playtimes = players.map { getRecentPlaytime($0) }
        let avgPlaytime = playtimes.reduce(0, +) / Double(playtimes.count)
        let playtimeVariance = playtimes.map { pow($0 - avgPlaytime, 2) }.reduce(0, +) / Double(playtimes.count)
        
        // Lower variance = better balance
        score -= playtimeVariance / 100.0
        
        return max(0, min(10, score))
    }
    
    private func getRecentPlaytime(_ player: Player) -> Double {
        let stats = player.statistics as? Set<PlayerStats> ?? []
        let recentStats = stats.filter { 
            guard let match = $0.match, let date = match.date else { return false }
            return date > Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        }
        return Double(recentStats.reduce(0) { $0 + Int($1.minutesPlayed) })
    }
    
    private func generateReasoning(
        lineup: [LineupPlayerPosition],
        formation: Formation,
        considerPlaytime: Bool,
        considerPerformance: Bool
    ) -> String {
        var reasons: [String] = []
        
        reasons.append("Suggested \(formation.displayName) formation")
        
        if considerPlaytime {
            reasons.append("Prioritized players with less recent playtime for balance")
        }
        
        if considerPerformance {
            reasons.append("Considered recent performance metrics")
        }
        
        let positionCounts = lineup.reduce(into: [LineupFieldPosition: Int]()) { counts, playerPos in
            counts[playerPos.position, default: 0] += 1
        }
        
        if let defenders = positionCounts[.defender], defenders >= 4 {
            reasons.append("Strong defensive setup")
        }
        
        if let midfielders = positionCounts[.midfielder], midfielders >= 4 {
            reasons.append("Midfield control focus")
        }
        
        if let forwards = positionCounts[.forward], forwards >= 3 {
            reasons.append("Attacking formation")
        }
        
        return reasons.joined(separator: ". ") + "."
    }
    
    // MARK: - Injury Management
    
    private func isInjured(_ player: Player) -> Bool {
        return player.isInjured
    }
    
    // MARK: - Formation Recommendations
    
    func recommendFormation(for team: Team, matchType: MatchType = .regular) -> [Formation] {
        let players = (team.players as? Set<Player>)?.filter { !isInjured($0) } ?? []
        let playersByPosition = Dictionary(grouping: players) { $0.position ?? "MID" }
        
        let goalkeepers = playersByPosition["GK"]?.count ?? 0
        let defenders = playersByPosition["DEF"]?.count ?? 0
        let midfielders = playersByPosition["MID"]?.count ?? 0
        let forwards = playersByPosition["FWD"]?.count ?? 0
        
        var recommendations: [Formation] = []
        
        // Basic formation recommendations based on available players
        if defenders >= 4 && midfielders >= 4 && forwards >= 2 {
            recommendations.append(.fourFourTwo)
        }
        
        if defenders >= 3 && midfielders >= 5 && forwards >= 2 {
            recommendations.append(.threeFiveTwo)
        }
        
        if defenders >= 4 && midfielders >= 3 && forwards >= 3 {
            recommendations.append(.fourThreeThree)
        }
        
        if defenders >= 5 && midfielders >= 3 && forwards >= 2 {
            recommendations.append(.fiveThreeTwo)
        }
        
        if defenders >= 3 && midfielders >= 4 && forwards >= 3 {
            recommendations.append(.threeFourThree)
        }
        
        // If no specific recommendations, suggest balanced formations
        if recommendations.isEmpty {
            recommendations = [.fourFourTwo, .fourThreeThree, .threeFiveTwo]
        }
        
        // Sort by match type preference
        return recommendations.sorted { formation1, formation2 in
            getFormationScore(formation1, for: matchType) > getFormationScore(formation2, for: matchType)
        }
    }
    
    private func getFormationScore(_ formation: Formation, for matchType: MatchType) -> Double {
        switch (formation, matchType) {
        case (.fourFourTwo, .regular): return 9.0
        case (.fourThreeThree, .attacking): return 9.5
        case (.fiveThreeTwo, .defensive): return 9.5
        case (.threeFiveTwo, .midfield): return 9.0
        default: return 7.0
        }
    }
}

// MARK: - Data Models

struct LineupSuggestion {
    let formation: Formation
    let lineup: [LineupPlayerPosition]
    let bench: [Player]
    let reasoning: String
    let balanceScore: Double
}

struct LineupPlayerPosition {
    let player: Player
    let position: LineupFieldPosition
    let x: Double // 0.0 to 1.0 (left to right)
    let y: Double // 0.0 to 1.0 (bottom to top, where 0 is own goal)
}

enum LineupFieldPosition: String, CaseIterable {
    case goalkeeper = "GK"
    case defender = "DEF"
    case midfielder = "MID"
    case forward = "FWD"
    
    var displayName: String {
        switch self {
        case .goalkeeper: return "Goalkeeper"
        case .defender: return "Defender"
        case .midfielder: return "Midfielder"
        case .forward: return "Forward"
        }
    }
}

enum Formation: String, CaseIterable {
    case fourFourTwo = "4-4-2"
    case fourThreeThree = "4-3-3"
    case threeFiveTwo = "3-5-2"
    case threeFourThree = "3-4-3"
    case fiveThreeTwo = "5-3-2"
    
    var displayName: String {
        return rawValue
    }
    
    var positionRequirements: [LineupFieldPosition: Int] {
        switch self {
        case .fourFourTwo:
            return [.goalkeeper: 1, .defender: 4, .midfielder: 4, .forward: 2]
        case .fourThreeThree:
            return [.goalkeeper: 1, .defender: 4, .midfielder: 3, .forward: 3]
        case .threeFiveTwo:
            return [.goalkeeper: 1, .defender: 3, .midfielder: 5, .forward: 2]
        case .threeFourThree:
            return [.goalkeeper: 1, .defender: 3, .midfielder: 4, .forward: 3]
        case .fiveThreeTwo:
            return [.goalkeeper: 1, .defender: 5, .midfielder: 3, .forward: 2]
        }
    }
    
    func getDefenderPositions() -> [(x: Double, y: Double)] {
        switch self {
        case .fourFourTwo, .fourThreeThree:
            return [(0.2, 0.25), (0.4, 0.25), (0.6, 0.25), (0.8, 0.25)]
        case .threeFiveTwo, .threeFourThree:
            return [(0.25, 0.25), (0.5, 0.25), (0.75, 0.25)]
        case .fiveThreeTwo:
            return [(0.15, 0.25), (0.35, 0.25), (0.5, 0.25), (0.65, 0.25), (0.85, 0.25)]
        }
    }
    
    func getMidfielderPositions() -> [(x: Double, y: Double)] {
        switch self {
        case .fourFourTwo:
            return [(0.2, 0.5), (0.4, 0.5), (0.6, 0.5), (0.8, 0.5)]
        case .fourThreeThree:
            return [(0.3, 0.5), (0.5, 0.5), (0.7, 0.5)]
        case .threeFiveTwo:
            return [(0.15, 0.5), (0.35, 0.5), (0.5, 0.5), (0.65, 0.5), (0.85, 0.5)]
        case .threeFourThree:
            return [(0.25, 0.5), (0.45, 0.5), (0.55, 0.5), (0.75, 0.5)]
        case .fiveThreeTwo:
            return [(0.3, 0.5), (0.5, 0.5), (0.7, 0.5)]
        }
    }
    
    func getForwardPositions() -> [(x: Double, y: Double)] {
        switch self {
        case .fourFourTwo, .threeFiveTwo, .fiveThreeTwo:
            return [(0.4, 0.75), (0.6, 0.75)]
        case .fourThreeThree, .threeFourThree:
            return [(0.3, 0.75), (0.5, 0.75), (0.7, 0.75)]
        }
    }
    
    func getAllPositions() -> [(position: LineupFieldPosition, x: Double, y: Double)] {
        var positions: [(LineupFieldPosition, Double, Double)] = []
        
        // Goalkeeper
        positions.append((.goalkeeper, 0.5, 0.1))
        
        // Defenders
        for pos in getDefenderPositions() {
            positions.append((.defender, pos.x, pos.y))
        }
        
        // Midfielders
        for pos in getMidfielderPositions() {
            positions.append((.midfielder, pos.x, pos.y))
        }
        
        // Forwards
        for pos in getForwardPositions() {
            positions.append((.forward, pos.x, pos.y))
        }
        
        return positions
    }
}

enum MatchType: String, CaseIterable {
    case regular = "Regular"
    case attacking = "Attacking"
    case defensive = "Defensive"
    case midfield = "Midfield Control"
    
    var displayName: String {
        return rawValue
    }
}