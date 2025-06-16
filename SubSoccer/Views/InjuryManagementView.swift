import SwiftUI
import CoreData

struct InjuryManagementView: View {
    let team: Team
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var injuryService = InjuryManagementService.shared
    @State private var selectedPlayer: Player?
    @State private var showingInjuryForm = false
    @State private var showingPlayerDetail: Player?
    
    private var injuryStatistics: InjuryStatistics {
        injuryService.getInjuryStatistics(for: team)
    }
    
    private var injuredPlayers: [Player] {
        injuryService.getInjuredPlayers(from: team)
    }
    
    private var playersReturningThisWeek: [Player] {
        injuryService.getPlayersReturningThisWeek(from: team)
    }
    
    private var overdueReturns: [Player] {
        injuryService.getOverdueReturns(from: team)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Statistics Overview
                        statisticsOverview
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Injured Players
                        injuredPlayersSection
                        
                        // Returning Players
                        if !playersReturningThisWeek.isEmpty {
                            returningPlayersSection
                        }
                        
                        // Overdue Returns
                        if !overdueReturns.isEmpty {
                            overdueReturnsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Injury Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Report Injury") {
                        showingInjuryForm = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
        .sheet(isPresented: $showingInjuryForm) {
            InjuryReportForm(team: team, selectedPlayer: selectedPlayer) {
                selectedPlayer = nil
                showingInjuryForm = false
            }
        }
        .sheet(item: $showingPlayerDetail) { player in
            PlayerInjuryDetailView(player: player)
        }
    }
    
    private var statisticsOverview: some View {
        VStack(spacing: 16) {
            Text("Team Health Overview")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InjuryStatCard(
                    title: "Available",
                    value: "\(injuryStatistics.availablePlayers)",
                    subtitle: "of \(injuryStatistics.totalPlayers) players",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                InjuryStatCard(
                    title: "Injured",
                    value: "\(injuryStatistics.injuredPlayers)",
                    subtitle: String(format: "%.1f%% injury rate", injuryStatistics.injuryRate * 100),
                    color: .red,
                    icon: "bandage.fill"
                )
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: {
                    showingInjuryForm = true
                }) {
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.accentColor)
                        
                        Text("Report Injury")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Could implement bulk recovery feature
                }) {
                    VStack {
                        Image(systemName: "heart.circle")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Mark Recovery")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(12)
                }
                .disabled(injuredPlayers.isEmpty)
                .opacity(injuredPlayers.isEmpty ? 0.5 : 1.0)
            }
        }
    }
    
    private var injuredPlayersSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Currently Injured")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Text("\(injuredPlayers.count)")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            if injuredPlayers.isEmpty {
                EmptyInjuryStateView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(injuredPlayers, id: \.objectID) { player in
                        InjuredPlayerCard(player: player) {
                            showingPlayerDetail = player
                        }
                    }
                }
            }
        }
    }
    
    private var returningPlayersSection: some View {
        VStack(spacing: 12) {
            Text("Returning This Week")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVStack(spacing: 8) {
                ForEach(playersReturningThisWeek, id: \.objectID) { player in
                    ReturningPlayerCard(player: player)
                }
            }
        }
    }
    
    private var overdueReturnsSection: some View {
        VStack(spacing: 12) {
            Text("Overdue Returns")
                .font(AppTheme.subheadFont)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVStack(spacing: 8) {
                ForEach(overdueReturns, id: \.objectID) { player in
                    OverduePlayerCard(player: player)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InjuryStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(AppTheme.headerFont.bold())
                    .foregroundColor(AppTheme.primaryText)
                
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct InjuredPlayerCard: View {
    let player: Player
    let onTap: () -> Void
    
    private var injuryDuration: String {
        guard let injuryDate = player.injuryDate else { return "Unknown" }
        let days = Calendar.current.dateComponents([.day], from: injuryDate, to: Date()).day ?? 0
        return "\(days) days"
    }
    
    private var expectedReturn: String {
        guard let returnDate = player.returnToPlayDate else { return "TBD" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: returnDate)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(AppTheme.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("\(player.jerseyNumber)")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.primaryText)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name ?? "Unknown")
                        .font(AppTheme.bodyFont.bold())
                        .foregroundColor(AppTheme.primaryText)
                    
                    Text(player.injuryDescription ?? "No details")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(injuryDuration)
                        .font(AppTheme.captionFont)
                        .foregroundColor(.orange)
                    
                    Text("Return: \(expectedReturn)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .cornerRadius(8)
        }
    }
}

struct ReturningPlayerCard: View {
    let player: Player
    
    private var daysUntilReturn: Int {
        guard let returnDate = player.returnToPlayDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: returnDate).day ?? 0
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name ?? "Unknown")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Expected return in \(daysUntilReturn) days")
                    .font(AppTheme.captionFont)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

struct OverduePlayerCard: View {
    let player: Player
    
    private var daysOverdue: Int {
        guard let returnDate = player.returnToPlayDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: returnDate, to: Date()).day ?? 0
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name ?? "Unknown")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Overdue by \(daysOverdue) days")
                    .font(AppTheme.captionFont)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

struct EmptyInjuryStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            VStack(spacing: 4) {
                Text("No Injuries")
                    .font(AppTheme.bodyFont.bold())
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Great job keeping the team healthy!")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.secondaryBackground.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Injury Report Form

struct InjuryReportForm: View {
    let team: Team
    let selectedPlayer: Player?
    let onComplete: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var injuryService = InjuryManagementService.shared
    
    @State private var selectedPlayerLocal: Player?
    @State private var injuryDescription = ""
    @State private var injuryDate = Date()
    @State private var expectedReturnDate: Date?
    @State private var useReturnDate = false
    @State private var selectedSeverity: InjurySeverity = .minor
    
    private var availablePlayers: [Player] {
        injuryService.getAvailablePlayers(from: team)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                Form {
                    Section("Player") {
                        Picker("Select Player", selection: $selectedPlayerLocal) {
                            Text("Choose a player...")
                                .tag(nil as Player?)
                            
                            ForEach(availablePlayers, id: \.objectID) { player in
                                Text("\(player.name ?? "Unknown") (#\(player.jerseyNumber))")
                                    .tag(player as Player?)
                            }
                        }
                    }
                    
                    Section("Injury Details") {
                        TextField("Description", text: $injuryDescription, axis: .vertical)
                            .lineLimit(3...6)
                        
                        Picker("Severity", selection: $selectedSeverity) {
                            ForEach(InjurySeverity.allCases, id: \.self) { severity in
                                Text(severity.displayName)
                                    .tag(severity)
                            }
                        }
                        
                        DatePicker("Injury Date", selection: $injuryDate, displayedComponents: .date)
                    }
                    
                    Section("Recovery") {
                        Toggle("Set Expected Return Date", isOn: $useReturnDate)
                        
                        if useReturnDate {
                            DatePicker("Expected Return", selection: Binding(
                                get: { expectedReturnDate ?? Calendar.current.date(byAdding: .day, value: selectedSeverity.estimatedRecoveryDays, to: injuryDate) ?? Date() },
                                set: { expectedReturnDate = $0 }
                            ), displayedComponents: .date)
                        } else {
                            Text("Estimated: \(selectedSeverity.estimatedRecoveryDays) days")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.primaryBackground)
            }
            .navigationTitle("Report Injury")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInjury()
                    }
                    .foregroundColor(AppTheme.accentColor)
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            selectedPlayerLocal = selectedPlayer
            if useReturnDate && expectedReturnDate == nil {
                expectedReturnDate = Calendar.current.date(byAdding: .day, value: selectedSeverity.estimatedRecoveryDays, to: injuryDate)
            }
        }
    }
    
    private var canSave: Bool {
        selectedPlayerLocal != nil && !injuryDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveInjury() {
        guard let player = selectedPlayerLocal else { return }
        
        let returnDate = useReturnDate ? expectedReturnDate : nil
        
        injuryService.markPlayerAsInjured(
            player: player,
            description: injuryDescription,
            injuryDate: injuryDate,
            expectedReturnDate: returnDate,
            in: viewContext
        )
        
        onComplete()
    }
}

// MARK: - Player Injury Detail View

struct PlayerInjuryDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var injuryService = InjuryManagementService.shared
    @State private var showingRecoveryConfirmation = false
    @State private var showingEditForm = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        playerHeaderView
                        injuryDetailsView
                        recoveryTimelineView
                        actionsView
                    }
                    .padding()
                }
            }
            .navigationTitle("Injury Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditForm = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
        .alert("Mark as Recovered", isPresented: $showingRecoveryConfirmation) {
            Button("Mark Recovered") {
                markAsRecovered()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure \(player.name ?? "this player") has fully recovered and is ready to play?")
        }
    }
    
    private var playerHeaderView: some View {
        HStack {
            Circle()
                .fill(AppTheme.accentColor.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.title2.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name ?? "Unknown Player")
                    .font(AppTheme.headerFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text(player.position ?? "No Position")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
        }
    }
    
    private var injuryDetailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Injury Details")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(title: "Description", value: player.injuryDescription ?? "No description")
                
                if let injuryDate = player.injuryDate {
                    DetailRow(title: "Injury Date", value: DateFormatter.mediumDate.string(from: injuryDate))
                }
                
                if let returnDate = player.returnToPlayDate {
                    DetailRow(title: "Expected Return", value: DateFormatter.mediumDate.string(from: returnDate))
                }
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
        }
    }
    
    private var recoveryTimelineView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Timeline")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            // Could add more detailed timeline view here
            Text("Recovery tracking coming soon...")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
                .italic()
        }
    }
    
    private var actionsView: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingRecoveryConfirmation = true
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Mark as Recovered")
                }
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.green)
                .cornerRadius(12)
            }
        }
    }
    
    private func markAsRecovered() {
        injuryService.markPlayerAsRecovered(player: player, in: viewContext)
        dismiss()
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}