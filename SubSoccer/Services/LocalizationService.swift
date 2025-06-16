import Foundation

/// Service for managing localization throughout the app
class LocalizationService: ObservableObject {
    static let shared = LocalizationService()
    
    private init() {}
    
    /// Get localized string for a key
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, comment: comment)
    }
    
    /// Get localized string with parameters
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
    
    /// Get current language code
    var currentLanguageCode: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// Check if current language is right-to-left
    var isRTL: Bool {
        return Locale.current.language.characterDirection == .rightToLeft
    }
}

// MARK: - Convenience Extensions

extension String {
    /// Get localized version of this string
    var localized: String {
        return LocalizationService.shared.localizedString(for: self)
    }
    
    /// Get localized version with parameters
    func localized(with arguments: CVarArg...) -> String {
        return LocalizationService.shared.localizedString(for: self, arguments: arguments)
    }
}

// MARK: - Localization Keys

/// Centralized localization keys to avoid typos
struct LocalizationKeys {
    // MARK: - Navigation
    static let teams = "teams"
    static let matches = "matches"
    static let calendar = "calendar"
    static let settings = "settings"
    
    // MARK: - Teams
    static let teamsTitle = "teams_title"
    static let noTeamsYet = "no_teams_yet"
    static let noTeamsDescription = "no_teams_description"
    static let addTeam = "add_team"
    static let editTeam = "edit_team"
    static let deleteTeam = "delete_team"
    static let teamName = "team_name"
    static let enterTeamName = "enter_team_name"
    static let newTeam = "new_team"
    static let teamDetails = "team_details"
    static let managePlayers = "manage_players"
    static let managePlayersDescription = "manage_players_description"
    static let created = "created"
    static let playersCount = "players_count"
    
    // MARK: - Players
    static let playersTitle = "players_title"
    static let noPlayersYet = "no_players_yet"
    static let noPlayersDescription = "no_players_description"
    static let noPlayersFound = "no_players_found"
    static let searchAdjustment = "search_adjustment"
    static let searchPlayersPlaceholder = "search_players_placeholder"
    static let addPlayer = "add_player"
    static let editPlayer = "edit_player"
    static let deletePlayer = "delete_player"
    static let newPlayer = "new_player"
    static let playerName = "player_name"
    static let enterPlayerName = "enter_player_name"
    static let jerseyNumber = "jersey_number"
    static let position = "position"
    static let goalkeeper = "goalkeeper"
    static let defender = "defender"
    static let midfielder = "midfielder"
    static let forward = "forward"
    static let addPhoto = "add_photo"
    static let changePhoto = "change_photo"
    static let unnamedPlayer = "unnamed_player"
    static let noPosition = "no_position"
    static let playerDetails = "player_details"
    static let unknownPlayer = "unknown_player"
    
    // MARK: - Positions
    static let positionGK = "position_gk"
    static let positionDEF = "position_def"
    static let positionMID = "position_mid"
    static let positionFWD = "position_fwd"
    
    // MARK: - Statistics
    static let goals = "goals"
    static let assists = "assists"
    static let minutes = "minutes"
    static let allTime = "all_time"
    static let lastMonth = "last_month"
    static let lastWeek = "last_week"
    static let recentMatches = "recent_matches"
    static let noMatchesPlayed = "no_matches_played"
    
    // MARK: - Common Actions
    static let cancel = "cancel"
    static let save = "save"
    static let done = "done"
    static let edit = "edit"
    static let delete = "delete"
    static let add = "add"
    static let loading = "loading"
    static let loadingPlayers = "loading_players"
    static let loadingMore = "loading_more"
    
    // MARK: - Accessibility
    static let teamsTabHint = "teams_tab_hint"
    static let matchesTabHint = "matches_tab_hint"
    static let calendarTabHint = "calendar_tab_hint"
    static let settingsTabHint = "settings_tab_hint"
    static let addNewItem = "add_new_item"
    static let addTeamHint = "add_team_hint"
    static let chevronRight = "chevron_right"
    
    // MARK: - Error Messages
    static let errorDeletingTeam = "error_deleting_team"
    static let errorDeletingPlayer = "error_deleting_player"
    static let errorSavingTeam = "error_saving_team"
    static let errorSavingPlayer = "error_saving_player"
}

// MARK: - PlayerPosition Extension

extension PlayerPosition {
    var localizedDisplayName: String {
        switch self {
        case .goalkeeper: return LocalizationKeys.goalkeeper.localized
        case .defender: return LocalizationKeys.defender.localized
        case .midfielder: return LocalizationKeys.midfielder.localized
        case .forward: return LocalizationKeys.forward.localized
        }
    }
    
    var localizedShortName: String {
        switch self {
        case .goalkeeper: return LocalizationKeys.positionGK.localized
        case .defender: return LocalizationKeys.positionDEF.localized
        case .midfielder: return LocalizationKeys.positionMID.localized
        case .forward: return LocalizationKeys.positionFWD.localized
        }
    }
}

// MARK: - StatisticsTimeframe Extension

extension StatisticsTimeframe {
    var localizedDisplayName: String {
        switch self {
        case .allTime: return LocalizationKeys.allTime.localized
        case .lastMonth: return LocalizationKeys.lastMonth.localized
        case .lastWeek: return LocalizationKeys.lastWeek.localized
        }
    }
}