import Foundation
import CoreData
import SwiftUI

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0
    
    private let supabaseService = SupabaseService.shared
    private var syncTimer: Timer?
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case completed
        case failed(Error)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .idle:
                return "Ready to sync"
            case .syncing:
                return "Syncing..."
            case .completed:
                return "Sync completed"
            case .failed(let error):
                return "Sync failed: \(error.localizedDescription)"
            }
        }
    }
    
    private init() {
        loadLastSyncDate()
        startAutoSync()
    }
    
    // MARK: - Public Methods
    
    func startManualSync() async {
        guard syncStatus != .syncing else { return }
        await performSync()
    }
    
    func enableAutoSync(interval: TimeInterval = 300) { // 5 minutes default
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                if self.supabaseService.isAuthenticated && self.syncStatus != .syncing {
                    await self.performSync()
                }
            }
        }
    }
    
    func disableAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func startAutoSync() {
        if UserDefaults.standard.bool(forKey: "autoSyncEnabled") {
            let interval = UserDefaults.standard.double(forKey: "autoSyncInterval")
            enableAutoSync(interval: interval > 0 ? interval : 300)
        }
    }
    
    private func performSync() async {
        guard supabaseService.isAuthenticated else {
            syncStatus = .failed(SyncError.notAuthenticated)
            return
        }
        
        syncStatus = .syncing
        syncProgress = 0.0
        
        do {
            // Step 1: Push local changes to Supabase
            syncProgress = 0.1
            try await pushLocalChanges()
            
            // Step 2: Pull remote changes from Supabase
            syncProgress = 0.5
            try await pullRemoteChanges()
            
            // Step 3: Resolve conflicts if any
            syncProgress = 0.8
            try await resolveConflicts()
            
            // Step 4: Complete sync
            syncProgress = 1.0
            syncStatus = .completed
            lastSyncDate = Date()
            saveLastSyncDate()
            
            // Reset status after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .completed = self.syncStatus {
                    self.syncStatus = .idle
                }
            }
            
        } catch {
            syncStatus = .failed(error)
            print("Sync failed: \(error)")
        }
    }
    
    private func pushLocalChanges() async throws {
        // This would push all modified local entities to Supabase
        // For now, this is a placeholder implementation
        
        let context = PersistenceController.shared.container.viewContext
        
        // Push teams that need syncing
        let teamFetch: NSFetchRequest<Team> = Team.fetchRequest()
        teamFetch.predicate = NSPredicate(format: "needsSync == true OR lastSynced == nil")
        
        let teams = try context.fetch(teamFetch)
        
        for team in teams {
            let remoteTeam = RemoteTeam(
                id: team.id?.uuidString ?? UUID().uuidString,
                name: team.name ?? "",
                created_at: team.createdAt ?? Date(),
                updated_at: Date(),
                user_id: supabaseService.currentUser?.id.uuidString ?? ""
            )
            
            try await supabaseService.uploadTeam(remoteTeam)
            
            // Mark as synced
            team.setValue(false, forKey: "needsSync")
            team.setValue(Date(), forKey: "lastSynced")
        }
        
        try context.save()
    }
    
    private func pullRemoteChanges() async throws {
        // This would pull all remote changes and update local Core Data
        // For now, this is a placeholder implementation
        
        let context = PersistenceController.shared.container.viewContext
        
        // Pull teams from Supabase
        let remoteTeams = try await supabaseService.syncTeams()
        
        for remoteTeam in remoteTeams {
            // Check if team exists locally
            let teamFetch: NSFetchRequest<Team> = Team.fetchRequest()
            teamFetch.predicate = NSPredicate(format: "id == %@", remoteTeam.id)
            
            let existingTeams = try context.fetch(teamFetch)
            
            let team: Team
            if let existingTeam = existingTeams.first {
                team = existingTeam
            } else {
                team = Team(context: context)
                team.id = UUID(uuidString: remoteTeam.id)
            }
            
            team.name = remoteTeam.name
            team.createdAt = remoteTeam.created_at
            team.setValue(Date(), forKey: "lastSynced")
            team.setValue(false, forKey: "needsSync")
        }
        
        try context.save()
    }
    
    private func resolveConflicts() async throws {
        // Implement conflict resolution logic
        // For now, remote changes take precedence (last-write-wins)
        
        // In a more sophisticated implementation, you might:
        // 1. Compare timestamps
        // 2. Show conflict resolution UI to user
        // 3. Implement field-level merging
    }
    
    private func loadLastSyncDate() {
        if let data = UserDefaults.standard.data(forKey: "lastSyncDate"),
           let date = try? JSONDecoder().decode(Date.self, from: data) {
            lastSyncDate = date
        }
    }
    
    private func saveLastSyncDate() {
        if let data = try? JSONEncoder().encode(lastSyncDate) {
            UserDefaults.standard.set(data, forKey: "lastSyncDate")
        }
    }
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case pushFailed(Error)
    case pullFailed(Error)
    case conflictResolutionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .pushFailed(let error):
            return "Failed to push local changes: \(error.localizedDescription)"
        case .pullFailed(let error):
            return "Failed to pull remote changes: \(error.localizedDescription)"
        case .conflictResolutionFailed(let error):
            return "Failed to resolve conflicts: \(error.localizedDescription)"
        }
    }
}

// MARK: - Core Data Extensions for Sync
// Note: needsSync and lastSynced properties are now defined in the CoreData model