import SwiftUI
import CoreData

struct MatchHistoryView: View {
    let team: Team
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest private var matches: FetchedResults<Match>
    @State private var selectedMatch: Match?
    @State private var showingMatchDetail = false
    @State private var showingExportOptions = false
    @State private var sortOrder: MatchSortOrder = .dateDescending
    @State private var filterOption: MatchFilterOption = .all
    
    init(team: Team) {
        self.team = team
        self._matches = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Match.date, ascending: false)],
            predicate: NSPredicate(format: "team == %@", team)
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter and sort controls
                    filterSortControlsView
                    
                    if filteredMatches.isEmpty {
                        emptyStateView
                    } else {
                        // Matches list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredMatches, id: \.objectID) { match in
                                    MatchHistoryCard(match: match)
                                        .onTapGesture {
                                            selectedMatch = match
                                            showingMatchDetail = true
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Match History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingMatchDetail) {
                if let match = selectedMatch {
                    MatchDetailView(match: match)
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(match: nil, team: team, trainingSession: nil)
            }
        }
    }
    
    private var filterSortControlsView: some View {
        VStack(spacing: 12) {
            HStack {
                // Filter picker
                Picker("Filter", selection: $filterOption) {
                    ForEach(MatchFilterOption.allCases, id: \.self) { option in
                        Text(option.displayName)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                // Sort picker
                Picker("Sort", selection: $sortOrder) {
                    ForEach(MatchSortOrder.allCases, id: \.self) { order in
                        Text(order.displayName)
                            .tag(order)
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(AppTheme.primaryText)
            }
            
            Divider()
                .background(AppTheme.secondaryText)
        }
        .padding(.horizontal)
        .padding(.top)
        .background(AppTheme.secondaryBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.secondaryText)
            
            VStack(spacing: 8) {
                Text("No Matches Found")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Start playing matches to see your match history here")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filteredMatches: [Match] {
        let allMatches = Array(matches)
        
        // Apply filter
        let filtered: [Match]
        switch filterOption {
        case .all:
            filtered = allMatches
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            filtered = allMatches.filter { ($0.date ?? Date()) >= weekAgo }
        case .thisMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            filtered = allMatches.filter { ($0.date ?? Date()) >= monthAgo }
        case .lastThreeMonths:
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            filtered = allMatches.filter { ($0.date ?? Date()) >= threeMonthsAgo }
        }
        
        // Apply sort
        return filtered.sorted { match1, match2 in
            switch sortOrder {
            case .dateAscending:
                return (match1.date ?? Date()) < (match2.date ?? Date())
            case .dateDescending:
                return (match1.date ?? Date()) > (match2.date ?? Date())
            case .durationAscending:
                return match1.duration < match2.duration
            case .durationDescending:
                return match1.duration > match2.duration
            }
        }
    }
}

// MARK: - Supporting Views

struct MatchHistoryCard: View {
    let match: Match
    @State private var showingExportOptions = false
    
    private var totalGoals: Int {
        match.playerStatsArray.reduce(0) { $0 + Int($1.goals) }
    }
    
    private var totalAssists: Int {
        match.playerStatsArray.reduce(0) { $0 + Int($1.assists) }
    }
    
    private var topScorer: PlayerStats? {
        match.playerStatsArray.max { Int($0.goals) < Int($1.goals) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.team?.name ?? "Unknown Team")
                        .font(AppTheme.bodyFont.bold())
                        .foregroundColor(AppTheme.primaryText)
                    
                    Text(formattedDate)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Button(action: {
                            showingExportOptions = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(AppTheme.accentColor)
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formattedDuration)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.accentColor)
                            
                            Text("\(match.numberOfHalves) halves")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                }
            }
            
            // Stats summary
            HStack(spacing: 24) {
                StatItem(icon: "soccer.ball", value: "\(totalGoals)", label: "Goals")
                StatItem(icon: "hand.thumbsup", value: "\(totalAssists)", label: "Assists")
                StatItem(icon: "person.3", value: "\(match.playerStatsArray.count)", label: "Players")
            }
            
            // Top performer
            if let topScorer = topScorer, topScorer.goals > 0 {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("Top Scorer: \(topScorer.player?.name ?? "Unknown") (\(topScorer.goals) goals)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.accentColor.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(match: match, team: nil, trainingSession: nil)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: match.date ?? Date())
    }
    
    private var formattedDuration: String {
        let minutes = Int(match.duration)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.accentColor)
            
            Text(value)
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Match Detail View

struct MatchDetailView: View {
    let match: Match
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportOptions = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Match info header
                        matchInfoSection
                        
                        // Player participation grid
                        participationGridSection
                        
                        // Match timeline (simplified)
                        timelineSection
                        
                        // Final statistics
                        finalStatisticsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Match Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(match: match, team: nil, trainingSession: nil)
            }
        }
    }
    
    private var matchInfoSection: some View {
        VStack(spacing: 16) {
            Text(match.team?.name ?? "Unknown Team")
                .font(AppTheme.headerFont)
                .foregroundColor(AppTheme.primaryText)
            
            HStack(spacing: 32) {
                InfoCard(title: "Duration", value: "\(match.duration) min", icon: "clock")
                InfoCard(title: "Halves", value: "\(match.numberOfHalves)", icon: "circle.grid.2x2")
                InfoCard(title: "Overtime", value: match.hasOvertime ? "Yes" : "No", icon: "plus.circle")
            }
        }
    }
    
    private var participationGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Participation")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(match.playerStatsArray, id: \.objectID) { stats in
                    PlayerParticipationCard(stats: stats)
                }
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Match Timeline")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                TimelineItem(time: "0'", event: "Match started", isHighlighted: true)
                
                // Goals timeline
                ForEach(goalsTimeline, id: \.id) { goal in
                    TimelineItem(
                        time: "\(goal.minute)'",
                        event: "Goal by \(goal.playerName)",
                        isHighlighted: false
                    )
                }
                
                TimelineItem(time: "\(match.duration)'", event: "Match ended", isHighlighted: true)
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
        }
    }
    
    private var finalStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final Statistics")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MatchHistoryStatCard(
                    title: "Total Goals",
                    value: "\(totalGoals)",
                    icon: "soccer.ball",
                    color: AppTheme.accentColor
                )
                
                MatchHistoryStatCard(
                    title: "Total Assists",
                    value: "\(totalAssists)",
                    icon: "hand.thumbsup",
                    color: .blue
                )
                
                MatchHistoryStatCard(
                    title: "Players Used",
                    value: "\(match.playerStatsArray.count)",
                    icon: "person.3",
                    color: .orange
                )
                
                MatchHistoryStatCard(
                    title: "Total Playtime",
                    value: "\(totalMinutes) min",
                    icon: "clock",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalGoals: Int {
        match.playerStatsArray.reduce(0) { $0 + Int($1.goals) }
    }
    
    private var totalAssists: Int {
        match.playerStatsArray.reduce(0) { $0 + Int($1.assists) }
    }
    
    private var totalMinutes: Int {
        match.playerStatsArray.reduce(0) { $0 + Int($1.minutesPlayed) }
    }
    
    private var goalsTimeline: [GoalEvent] {
        match.playerStatsArray
            .filter { $0.goals > 0 }
            .flatMap { stats in
                (0..<Int(stats.goals)).map { _ in
                    GoalEvent(
                        id: UUID(),
                        playerName: stats.player?.name ?? "Unknown",
                        minute: Int.random(in: 1...Int(match.duration))
                    )
                }
            }
            .sorted { $0.minute < $1.minute }
    }
}

// MARK: - Supporting Views and Types

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppTheme.accentColor)
            
            Text(value)
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            Text(title)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

struct PlayerParticipationCard: View {
    let stats: PlayerStats
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(AppTheme.accentColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(stats.player?.jerseyNumber ?? 0)")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            Text(stats.player?.name ?? "Unknown")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.primaryText)
                .lineLimit(1)
            
            VStack(spacing: 2) {
                Text("\(stats.minutesPlayed) min")
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
                
                HStack(spacing: 8) {
                    Text("\(stats.goals)G")
                        .font(.caption2)
                        .foregroundColor(AppTheme.accentColor)
                    
                    Text("\(stats.assists)A")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(8)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

struct TimelineItem: View {
    let time: String
    let event: String
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(time)
                .font(.caption.monospaced())
                .foregroundColor(isHighlighted ? AppTheme.accentColor : AppTheme.secondaryText)
                .frame(width: 40, alignment: .leading)
            
            Circle()
                .fill(isHighlighted ? AppTheme.accentColor : AppTheme.secondaryText)
                .frame(width: 8, height: 8)
            
            Text(event)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.primaryText)
            
            Spacer()
        }
    }
}

struct GoalEvent {
    let id: UUID
    let playerName: String
    let minute: Int
}

struct MatchHistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            Text(title)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

enum MatchSortOrder: CaseIterable {
    case dateAscending
    case dateDescending
    case durationAscending
    case durationDescending
    
    var displayName: String {
        switch self {
        case .dateAscending:
            return "Date (Oldest First)"
        case .dateDescending:
            return "Date (Newest First)"
        case .durationAscending:
            return "Duration (Shortest First)"
        case .durationDescending:
            return "Duration (Longest First)"
        }
    }
}

enum MatchFilterOption: CaseIterable {
    case all
    case thisWeek
    case thisMonth
    case lastThreeMonths
    
    var displayName: String {
        switch self {
        case .all:
            return "All Matches"
        case .thisWeek:
            return "This Week"
        case .thisMonth:
            return "This Month"
        case .lastThreeMonths:
            return "Last 3 Months"
        }
    }
}

// MARK: - Extensions