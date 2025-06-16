import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    
    @AppStorage("enableMatchReminders") private var enableMatchReminders = true
    @AppStorage("matchReminderMinutes") private var matchReminderMinutes = 60
    @AppStorage("enableTrainingReminders") private var enableTrainingReminders = true
    @AppStorage("trainingReminderMinutes") private var trainingReminderMinutes = 30
    @AppStorage("enableSubstitutionReminders") private var enableSubstitutionReminders = true
    @AppStorage("substitutionReminderMinutes") private var substitutionReminderMinutes = 5
    @AppStorage("enableReturnToPlayReminders") private var enableReturnToPlayReminders = true
    
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                Form {
                    // Permission Section
                    Section {
                        permissionStatusView
                    } header: {
                        Text("Notification Permission")
                    }
                    
                    // Match Notifications
                    Section {
                        Toggle("Match Reminders", isOn: $enableMatchReminders)
                            .tint(AppTheme.accentColor)
                            .disabled(!notificationService.isAuthorized)
                        
                        if enableMatchReminders {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Remind me \(matchReminderMinutes) minutes before matches")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Slider(value: Binding(
                                    get: { Double(matchReminderMinutes) },
                                    set: { matchReminderMinutes = Int($0) }
                                ), in: 15...120, step: 15)
                                .tint(AppTheme.accentColor)
                                .disabled(!notificationService.isAuthorized)
                            }
                        }
                    } header: {
                        Text("Match Notifications")
                    } footer: {
                        Text("Get notified before matches start to prepare your team")
                    }
                    
                    // Training Notifications
                    Section {
                        Toggle("Training Reminders", isOn: $enableTrainingReminders)
                            .tint(AppTheme.accentColor)
                            .disabled(!notificationService.isAuthorized)
                        
                        if enableTrainingReminders {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Remind me \(trainingReminderMinutes) minutes before training")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Slider(value: Binding(
                                    get: { Double(trainingReminderMinutes) },
                                    set: { trainingReminderMinutes = Int($0) }
                                ), in: 10...60, step: 10)
                                .tint(AppTheme.accentColor)
                                .disabled(!notificationService.isAuthorized)
                            }
                        }
                    } header: {
                        Text("Training Notifications")
                    } footer: {
                        Text("Get notified before training sessions")
                    }
                    
                    // In-Match Notifications
                    Section {
                        Toggle("Substitution Reminders", isOn: $enableSubstitutionReminders)
                            .tint(AppTheme.accentColor)
                            .disabled(!notificationService.isAuthorized)
                        
                        if enableSubstitutionReminders {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Remind me every \(substitutionReminderMinutes) minutes during matches")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Picker("Interval", selection: $substitutionReminderMinutes) {
                                    Text("3 minutes").tag(3)
                                    Text("5 minutes").tag(5)
                                    Text("10 minutes").tag(10)
                                    Text("15 minutes").tag(15)
                                }
                                .pickerStyle(.segmented)
                                .disabled(!notificationService.isAuthorized)
                            }
                        }
                    } header: {
                        Text("In-Match Notifications")
                    } footer: {
                        Text("Get reminders to rotate players during live matches")
                    }
                    
                    // Injury Management Notifications
                    Section {
                        Toggle("Return to Play Reminders", isOn: $enableReturnToPlayReminders)
                            .tint(AppTheme.accentColor)
                            .disabled(!notificationService.isAuthorized)
                    } header: {
                        Text("Injury Management")
                    } footer: {
                        Text("Get notified when injured players are ready to return")
                    }
                    
                    // Management Section
                    Section {
                        Button("View Pending Notifications") {
                            Task {
                                await notificationService.getPendingNotifications()
                            }
                        }
                        .foregroundColor(AppTheme.accentColor)
                        .disabled(!notificationService.isAuthorized)
                        
                        Button("Cancel All Notifications") {
                            notificationService.cancelAllNotifications()
                        }
                        .foregroundColor(.red)
                        .disabled(!notificationService.isAuthorized)
                    } header: {
                        Text("Notification Management")
                    }
                    
                    // Pending Notifications List
                    if !notificationService.pendingNotifications.isEmpty {
                        Section {
                            ForEach(notificationService.pendingNotifications, id: \.identifier) { request in
                                PendingNotificationRow(request: request)
                            }
                        } header: {
                            Text("Pending Notifications (\(notificationService.pendingNotifications.count))")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.primaryBackground)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To receive notifications, please enable them in Settings > Notifications > SubSoccer")
        }
        .task {
            await notificationService.getPendingNotifications()
        }
    }
    
    private var permissionStatusView: some View {
        HStack {
            Image(systemName: notificationService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(notificationService.isAuthorized ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notificationService.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text(notificationService.isAuthorized ? "You'll receive notifications based on your settings below" : "Enable notifications to get reminders and alerts")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            if !notificationService.isAuthorized {
                Button("Enable") {
                    Task {
                        let granted = await notificationService.requestNotificationPermission()
                        if !granted {
                            showingPermissionAlert = true
                        }
                    }
                }
                .foregroundColor(AppTheme.accentColor)
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

struct PendingNotificationRow: View {
    let request: UNNotificationRequest
    
    private var triggerDescription: String {
        if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            if let nextTriggerDate = calendarTrigger.nextTriggerDate() {
                return formatter.string(from: nextTriggerDate)
            }
        } else if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            let minutes = Int(intervalTrigger.timeInterval / 60)
            return "In \(minutes) minutes"
        }
        
        return "Unknown"
    }
    
    private var notificationType: String {
        if let type = request.content.userInfo["type"] as? String {
            switch type {
            case "match_reminder":
                return "Match Reminder"
            case "match_start":
                return "Match Start"
            case "training_reminder":
                return "Training Reminder"
            case "substitution_reminder":
                return "Substitution Reminder"
            case "return_to_play":
                return "Return to Play"
            default:
                return "Unknown"
            }
        }
        return "Unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(notificationType)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Text(triggerDescription)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Text(request.content.body)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(2)
        }
    }
}

// MARK: - Quick Setup View

struct NotificationQuickSetupView: View {
    let onComplete: () -> Void
    @StateObject private var notificationService = NotificationService.shared
    @State private var currentStep = 0
    
    private let steps = [
        QuickSetupStep(
            title: "Enable Notifications",
            description: "Get reminders for matches and training sessions",
            icon: "bell.fill"
        ),
        QuickSetupStep(
            title: "Match Reminders",
            description: "Never miss a match with timely notifications",
            icon: "soccerball"
        ),
        QuickSetupStep(
            title: "Training Alerts",
            description: "Stay on top of training schedules",
            icon: "figure.run"
        ),
        QuickSetupStep(
            title: "You're All Set!",
            description: "Notifications are configured and ready to go",
            icon: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Progress Indicator
                    HStack {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep ? AppTheme.accentColor : AppTheme.secondaryText.opacity(0.3))
                                .frame(width: 12, height: 12)
                            
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(index < currentStep ? AppTheme.accentColor : AppTheme.secondaryText.opacity(0.3))
                                    .frame(height: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Current Step Content
                    VStack(spacing: 24) {
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 64))
                            .foregroundColor(AppTheme.accentColor)
                        
                        VStack(spacing: 8) {
                            Text(steps[currentStep].title)
                                .font(AppTheme.headerFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            Text(steps[currentStep].description)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                    
                    // Action Button
                    Button(action: handleStepAction) {
                        Text(stepButtonTitle)
                            .font(AppTheme.bodyFont.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Notification Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onComplete()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }
    
    private var stepButtonTitle: String {
        switch currentStep {
        case 0:
            return "Enable Notifications"
        case steps.count - 1:
            return "Get Started"
        default:
            return "Next"
        }
    }
    
    private func handleStepAction() {
        switch currentStep {
        case 0:
            Task {
                let granted = await notificationService.requestNotificationPermission()
                if granted {
                    withAnimation {
                        currentStep += 1
                    }
                }
            }
        case steps.count - 1:
            onComplete()
        default:
            withAnimation {
                currentStep += 1
            }
        }
    }
}

struct QuickSetupStep {
    let title: String
    let description: String
    let icon: String
}