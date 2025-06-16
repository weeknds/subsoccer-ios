import Foundation
import UserNotifications
import CoreData

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Match Notifications
    
    func scheduleMatchReminder(for match: Match, minutesBefore: Int = 60) {
        guard let matchDate = match.date,
              let teamName = match.team?.name else {
            return
        }
        
        let reminderDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: matchDate)
        guard let reminderDate = reminderDate, reminderDate > Date() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Match Reminder"
        content.body = "\(teamName) has a match in \(minutesBefore) minutes!"
        content.sound = .default
        content.badge = 1
        
        // Add match details to user info
        content.userInfo = [
            "type": "match_reminder",
            "match_id": match.id?.uuidString ?? "",
            "team_name": teamName,
            "minutes_before": minutesBefore
        ]
        
        let identifier = "match_reminder_\(match.id?.uuidString ?? "")"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule match reminder: \(error)")
            }
        }
    }
    
    func scheduleMatchStartNotification(for match: Match) {
        guard let matchDate = match.date,
              let teamName = match.team?.name else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Match Starting!"
        content.body = "Time to start the \(teamName) match!"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "match_start",
            "match_id": match.id?.uuidString ?? "",
            "team_name": teamName
        ]
        
        let identifier = "match_start_\(match.id?.uuidString ?? "")"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: matchDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule match start notification: \(error)")
            }
        }
    }
    
    // MARK: - Training Session Notifications
    
    func scheduleTrainingReminder(for session: TrainingSession, minutesBefore: Int = 30) {
        guard let sessionDate = session.date,
              let teamName = session.team?.name else {
            return
        }
        
        let reminderDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: sessionDate)
        guard let reminderDate = reminderDate, reminderDate > Date() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Training Reminder"
        content.body = "\(teamName) has training in \(minutesBefore) minutes!"
        if let location = session.location, !location.isEmpty {
            content.body += " at \(location)"
        }
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "training_reminder",
            "session_id": session.id?.uuidString ?? "",
            "team_name": teamName,
            "minutes_before": minutesBefore
        ]
        
        let identifier = "training_reminder_\(session.id?.uuidString ?? "")"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule training reminder: \(error)")
            }
        }
    }
    
    // MARK: - Substitution Reminders
    
    func scheduleSubstitutionReminder(for match: Match, interval: TimeInterval = 300) { // 5 minutes default
        guard let teamName = match.team?.name else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Substitution Reminder"
        content.body = "Time to consider player substitutions for \(teamName)!"
        content.sound = .default
        content.categoryIdentifier = "SUBSTITUTION_REMINDER"
        
        content.userInfo = [
            "type": "substitution_reminder",
            "match_id": match.id?.uuidString ?? "",
            "team_name": teamName
        ]
        
        let identifier = "substitution_reminder_\(match.id?.uuidString ?? "")_\(Date().timeIntervalSince1970)"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule substitution reminder: \(error)")
            }
        }
    }
    
    // MARK: - Injury Management Notifications
    
    func scheduleReturnToPlayReminder(for player: Player) {
        guard let returnDate = player.returnToPlayDate,
              let playerName = player.name,
              let teamName = player.team?.name else {
            return
        }
        
        // Schedule reminder 1 day before return
        let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: returnDate)
        guard let reminderDate = reminderDate, reminderDate > Date() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Player Return Reminder"
        content.body = "\(playerName) is expected to return to play tomorrow for \(teamName)!"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "return_to_play",
            "player_id": player.id?.uuidString ?? "",
            "player_name": playerName,
            "team_name": teamName
        ]
        
        let identifier = "return_reminder_\(player.id?.uuidString ?? "")"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule return reminder: \(error)")
            }
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllMatchNotifications(for match: Match) {
        guard let matchId = match.id?.uuidString else { return }
        
        let identifiers = [
            "match_reminder_\(matchId)",
            "match_start_\(matchId)"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAllTrainingNotifications(for session: TrainingSession) {
        guard let sessionId = session.id?.uuidString else { return }
        
        let identifiers = [
            "training_reminder_\(sessionId)"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func getPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        await MainActor.run {
            pendingNotifications = requests
        }
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let substitutionAction = UNNotificationAction(
            identifier: "OPEN_SUBSTITUTIONS",
            title: "Open Substitutions",
            options: [.foreground]
        )
        
        let substitutionCategory = UNNotificationCategory(
            identifier: "SUBSTITUTION_REMINDER",
            actions: [substitutionAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([substitutionCategory])
    }
    
    // MARK: - Bulk Scheduling
    
    func scheduleAllUpcomingMatches(for team: Team) {
        let matches = (team.matches as? Set<Match>)?.filter { match in
            guard let date = match.date else { return false }
            return date > Date()
        } ?? []
        
        for match in matches {
            scheduleMatchReminder(for: match, minutesBefore: 60)
            scheduleMatchStartNotification(for: match)
        }
    }
    
    func scheduleAllUpcomingTrainingSessions(for team: Team) {
        let sessions = (team.trainingSessions as? Set<TrainingSession>)?.filter { session in
            guard let date = session.date else { return false }
            return date > Date()
        } ?? []
        
        for session in sessions {
            scheduleTrainingReminder(for: session, minutesBefore: 30)
        }
    }
    
    func scheduleAllReturnToPlayReminders(for team: Team) {
        let injuredPlayers = (team.players as? Set<Player>)?.filter { $0.isInjured } ?? []
        
        for player in injuredPlayers {
            scheduleReturnToPlayReminder(for: player)
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettings {
    var enableMatchReminders = true
    var matchReminderMinutes = 60
    var enableTrainingReminders = true
    var trainingReminderMinutes = 30
    var enableSubstitutionReminders = true
    var substitutionReminderMinutes = 5
    var enableReturnToPlayReminders = true
    
    static let shared = NotificationSettings()
}

// MARK: - Notification Types

enum NotificationType: String, CaseIterable {
    case matchReminder = "match_reminder"
    case matchStart = "match_start"
    case trainingReminder = "training_reminder"
    case substitutionReminder = "substitution_reminder"
    case returnToPlay = "return_to_play"
    
    var displayName: String {
        switch self {
        case .matchReminder:
            return "Match Reminders"
        case .matchStart:
            return "Match Start"
        case .trainingReminder:
            return "Training Reminders"
        case .substitutionReminder:
            return "Substitution Reminders"
        case .returnToPlay:
            return "Return to Play"
        }
    }
    
    var description: String {
        switch self {
        case .matchReminder:
            return "Get notified before matches start"
        case .matchStart:
            return "Get notified when matches begin"
        case .trainingReminder:
            return "Get notified before training sessions"
        case .substitutionReminder:
            return "Get reminders to rotate players during matches"
        case .returnToPlay:
            return "Get notified when injured players are ready to return"
        }
    }
}