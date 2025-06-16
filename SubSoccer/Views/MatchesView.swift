import SwiftUI
import CoreData

struct MatchesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Match.date, ascending: false)],
        animation: .default)
    private var matches: FetchedResults<Match>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>
    
    @State private var showingMatchSetup = false
    @State private var selectedMatch: Match?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack {
                    if matches.isEmpty {
                        emptyStateView
                    } else {
                        matchesListView
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        newMatchButton
                    }
                }
                .padding()
            }
            .navigationTitle("Matches")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !teams.isEmpty {
                            ForEach(teams, id: \.self) { team in
                                Menu(team.name ?? "Unknown Team") {
                                    NavigationLink("Statistics", destination: PlayerStatisticsView(team: team))
                                    NavigationLink("Match History", destination: MatchHistoryView(team: team))
                                }
                            }
                        } else {
                            Text("No teams available")
                        }
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingMatchSetup) {
                MatchSetupView()
            }
            .fullScreenCover(item: $selectedMatch) { match in
                LiveMatchView(match: match)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Modern icon with background circle
            ZStack {
                Circle()
                    .fill(AppTheme.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(AppTheme.accentColor)
            }
            
            VStack(spacing: 12) {
                Text("No Matches Yet")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Set up your first match to start tracking live games and substitutions")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Call to action hint
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.accentColor)
                
                Text("Tap the + button to set up a match")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
    
    private var matchesListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(matches, id: \.self) { match in
                    MatchCard(match: match) {
                        selectedMatch = match
                    }
                }
            }
            .padding()
        }
    }
    
    private var newMatchButton: some View {
        Button(action: {
            showingMatchSetup = true
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(AppTheme.accentColor)
                .clipShape(Circle())
                .shadow(color: AppTheme.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(teams.isEmpty)
        .opacity(teams.isEmpty ? 0.6 : 1.0)
    }
}

struct MatchCard: View {
    let match: Match
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var isUpcoming: Bool {
        guard let matchDate = match.date else { return false }
        return matchDate > Date()
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header with team and date
                HStack(spacing: 16) {
                    // Match icon
                    ZStack {
                        Circle()
                            .fill(isUpcoming ? AppTheme.accentColor.opacity(0.1) : AppTheme.secondaryText.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: isUpcoming ? "clock.fill" : "sportscourt.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isUpcoming ? AppTheme.accentColor : AppTheme.secondaryText)
                    }
                    
                    // Match info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.team?.name ?? "Unknown Team")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText)
                            .lineLimit(1)
                        
                        Text(dateFormatter.string(from: match.date ?? Date()))
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isUpcoming ? "UPCOMING" : "READY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isUpcoming ? AppTheme.accentColor : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isUpcoming ? AppTheme.accentColor.opacity(0.1) : Color.orange.opacity(0.1))
                            )
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
                .padding(20)
                
                // Match details
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                        Text("\(match.duration) min")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Halves")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                        Text("\(match.numberOfHalves)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText)
                    }
                    
                    if match.hasOvertime {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Overtime")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText)
                            Text("Enabled")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Play button
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Match")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentColor)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppTheme.secondaryBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.accentColor.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MatchSetupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>
    
    @State private var duration: Double = 90
    @State private var numberOfHalves: Int = 2
    @State private var hasOvertime: Bool = false
    @State private var selectedTeam: Team?
    @State private var matchDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        matchDateSection
                        teamSelectionSection
                        durationSection
                        halvesSection
                        overtimeSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Match Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createMatch()
                    }
                    .foregroundColor(AppTheme.accentColor)
                    .fontWeight(.semibold)
                    .disabled(selectedTeam == nil)
                }
            }
        }
    }
    
    private var matchDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Date & Time")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            DatePicker("Match Date", selection: $matchDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .tint(AppTheme.accentColor)
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
        }
    }
    
    private var teamSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Team")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            if teams.isEmpty {
                VStack(spacing: 8) {
                    Text("No teams available")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("Create a team first in the Teams tab")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
            } else {
                Menu {
                    ForEach(teams, id: \.self) { team in
                        Button(team.name ?? "Unknown Team") {
                            selectedTeam = team
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedTeam?.name ?? "Choose a team")
                            .foregroundColor(selectedTeam == nil ? AppTheme.secondaryText : AppTheme.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppTheme.secondaryText)
                            .font(.caption)
                    }
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
                }
            }
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Match Duration")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Text("\(Int(duration)) minutes")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.accentColor)
                    .fontWeight(.medium)
            }
            
            Slider(value: $duration, in: 30...120, step: 15)
                .tint(AppTheme.accentColor)
                .padding(.horizontal, 4)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private var halvesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Number of Halves")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            Picker("Halves", selection: $numberOfHalves) {
                ForEach(1...4, id: \.self) { number in
                    Text("\(number) \(number == 1 ? "Half" : "Halves")")
                        .tag(number)
                }
            }
            .pickerStyle(.segmented)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }
    
    private var overtimeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overtime")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Enable additional time if needed")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            Toggle("", isOn: $hasOvertime)
                .tint(AppTheme.accentColor)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private func createMatch() {
        guard let team = selectedTeam else { return }
        
        let newMatch = Match(context: viewContext)
        newMatch.id = UUID()
        newMatch.date = matchDate
        newMatch.duration = Int16(duration)
        newMatch.numberOfHalves = Int16(numberOfHalves)
        newMatch.hasOvertime = hasOvertime
        newMatch.team = team
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error creating match: \(error)")
        }
    }
}