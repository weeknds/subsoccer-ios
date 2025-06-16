import SwiftUI

struct SettingsView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var syncService = SyncService.shared
    @State private var showingAuthView = false
    @State private var showingNotificationSettings = false
    @State private var autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
    @State private var syncInterval = UserDefaults.standard.double(forKey: "autoSyncInterval")
    
    init() {
        if syncInterval == 0 {
            _syncInterval = State(initialValue: 300) // 5 minutes default
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.largePadding) {
                        // Account Section
                        accountSection
                        
                        // Sync Section
                        if supabaseService.isAuthenticated {
                            syncSection
                        }
                        
                        // Notifications Section
                        notificationSection
                        
                        // App Info Section
                        appInfoSection
                    }
                    .padding(AppTheme.largePadding)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAuthView) {
            AuthenticationView()
        }
        .onChange(of: supabaseService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                showingAuthView = false
            }
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .onChange(of: autoSyncEnabled) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "autoSyncEnabled")
            if newValue {
                syncService.enableAutoSync(interval: syncInterval)
            } else {
                syncService.disableAutoSync()
            }
        }
        .onChange(of: syncInterval) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "autoSyncInterval")
            if autoSyncEnabled {
                syncService.enableAutoSync(interval: newValue)
            }
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            Text("Account")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
            
            if supabaseService.isAuthenticated {
                // Signed In State
                VStack(spacing: AppTheme.standardPadding) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed In")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            if let email = supabaseService.currentUser?.email {
                                Text(email)
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Sign Out") {
                            Task {
                                try? await supabaseService.signOut()
                            }
                        }
                        .foregroundColor(.red)
                        .font(AppTheme.captionFont)
                    }
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
                }
            } else {
                // Signed Out State
                VStack(spacing: AppTheme.standardPadding) {
                    HStack {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not Signed In")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            Text("Sign in to sync across devices")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button("Sign In") {
                            showingAuthView = true
                        }
                        .foregroundColor(AppTheme.accentColor)
                        .font(AppTheme.captionFont)
                    }
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
                }
            }
        }
    }
    
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            Text("Sync Settings")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
            
            VStack(spacing: AppTheme.standardPadding) {
                // Sync Status
                HStack {
                    Image(systemName: syncStatusIcon)
                        .foregroundColor(syncStatusColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Status")
                            .font(AppTheme.subheadFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        Text(syncService.syncStatus.description)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    if case .syncing = syncService.syncStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Sync Now") {
                            Task {
                                await syncService.startManualSync()
                            }
                        }
                        .foregroundColor(AppTheme.accentColor)
                        .font(AppTheme.captionFont)
                    }
                }
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
                
                // Auto Sync Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Sync")
                            .font(AppTheme.subheadFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        Text("Automatically sync data in background")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoSyncEnabled)
                        .tint(AppTheme.accentColor)
                }
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
                
                // Sync Interval
                if autoSyncEnabled {
                    VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                        Text("Sync Interval")
                            .font(AppTheme.subheadFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        HStack {
                            Text("\(Int(syncInterval / 60)) minutes")
                                .foregroundColor(AppTheme.primaryText)
                            
                            Spacer()
                            
                            Slider(value: $syncInterval, in: 60...1800, step: 60) // 1-30 minutes
                                .accentColor(AppTheme.accentColor)
                                .frame(width: 200)
                        }
                    }
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
                }
                
                // Last Sync Date
                if let lastSync = syncService.lastSyncDate {
                    HStack {
                        Text("Last Sync")
                            .font(AppTheme.subheadFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        Spacer()
                        
                        Text(lastSync, style: .relative)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
                }
            }
        }
    }
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            Text("Notifications")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
            
            Button(action: {
                showingNotificationSettings = true
            }) {
                HStack {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notification Settings")
                            .font(AppTheme.subheadFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        Text("Configure match, training, and injury reminders")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
            }
        }
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            Text("App Information")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("SubSoccer")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Phase 6: Training Calendar Complete")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.accentColor)
                
                Text("iOS 18+ • Core Data • Supabase Integration")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
                
                Text("Version 1.0.0 (Build 1)")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }
    
    private var syncStatusIcon: String {
        switch syncService.syncStatus {
        case .idle:
            return "checkmark.circle"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .idle:
            return AppTheme.secondaryText
        case .syncing:
            return AppTheme.accentColor
        case .completed:
            return AppTheme.accentColor
        case .failed:
            return .red
        }
    }
}