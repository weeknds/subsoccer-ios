import SwiftUI
import Charts
import CoreData

struct PlayerStatisticsView: View {
    let team: Team
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest private var playerStats: FetchedResults<PlayerStats>
    @State private var selectedTimeframe: StatisticsTimeframe = .allTime
    @State private var selectedPlayer: Player?
    @State private var showingComparison = false
    @State private var showingExportOptions = false
    
    init(team: Team) {
        self.team = team
        self._playerStats = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \PlayerStats.minutesPlayed, ascending: false)],
            predicate: NSPredicate(format: "player.team == %@", team)
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with timeframe selector
                        headerView
                        
                        // Team overview cards
                        teamOverviewSection
                        
                        // Players statistics list
                        playersStatisticsSection
                        
                        // Charts section
                        chartsSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Statistics")
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
        .sheet(isPresented: $showingComparison) {
            if let player = selectedPlayer {
                PlayerComparisonView(team: team, selectedPlayer: player)
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(match: nil, team: team, trainingSession: nil)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Text(team.name ?? "Team Statistics")
                    .font(AppTheme.headerFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Button("Compare") {
                    showingComparison = true
                }
                .foregroundColor(AppTheme.accentColor)
                .font(AppTheme.bodyFont)
            }
            
            // Timeframe selector
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(StatisticsTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName)
                        .tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            .background(AppTheme.secondaryBackground)
        }
    }
    
    private var teamOverviewSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            StatCard(
                title: "Total Goals",
                value: "\(totalGoals)",
                icon: "soccerball",
                color: AppTheme.accentColor
            )
            
            StatCard(
                title: "Total Assists", 
                value: "\(totalAssists)",
                icon: "hand.thumbsup",
                color: .blue
            )
            
            StatCard(
                title: "Matches Played",
                value: "\(totalMatches)",
                icon: "calendar",
                color: .orange
            )
        }
    }
    
    private var playersStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Performance")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            LazyVStack(spacing: 12) {
                ForEach(sortedPlayers, id: \.objectID) { player in
                    PlayerStatsRow(player: player, stats: getPlayerStats(for: player))
                        .onTapGesture {
                            selectedPlayer = player
                        }
                }
            }
        }
    }
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Performance Charts")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            // Playtime distribution chart
            playtimeDistributionChart
            
            // Goals and assists chart
            goalsAssistsChart
        }
    }
    
    private var playtimeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playtime Distribution")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
            
            Chart(Array(playtimeData.prefix(8))) { data in
                SectorMark(
                    angle: .value("Minutes", data.minutes),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(data.color)
                .opacity(0.8)
            }
            .frame(height: 200)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                VStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Text("\(totalMinutes) min")
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)
                }
            )
        }
    }
    
    private var goalsAssistsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals & Assists")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
            
            Chart(Array(sortedPlayers.prefix(10))) { player in
                let stats = getPlayerStats(for: player)
                
                BarMark(
                    x: .value("Player", player.name ?? "Unknown"),
                    y: .value("Goals", stats.totalGoals)
                )
                .foregroundStyle(AppTheme.accentColor)
                .position(by: .value("Type", "Goals"))
                
                BarMark(
                    x: .value("Player", player.name ?? "Unknown"),
                    y: .value("Assists", stats.totalAssists)
                )
                .foregroundStyle(.blue)
                .position(by: .value("Type", "Assists"))
            }
            .frame(height: 200)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .chartLegend {
                HStack {
                    Label("Goals", systemImage: "circle.fill")
                        .foregroundColor(AppTheme.accentColor)
                    Label("Assists", systemImage: "circle.fill")
                        .foregroundColor(.blue)
                }
                .font(.caption)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredStats: [PlayerStats] {
        let stats = Array(playerStats)
        switch selectedTimeframe {
        case .allTime:
            return stats
        case .lastMonth:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return stats.filter { ($0.match?.date ?? Date()) >= oneMonthAgo }
        case .lastWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            return stats.filter { ($0.match?.date ?? Date()) >= oneWeekAgo }
        }
    }
    
    private var totalGoals: Int {
        filteredStats.reduce(0) { $0 + Int($1.goals) }
    }
    
    private var totalAssists: Int {
        filteredStats.reduce(0) { $0 + Int($1.assists) }
    }
    
    private var totalMatches: Int {
        Set(filteredStats.compactMap { $0.match }).count
    }
    
    private var totalMinutes: Int {
        filteredStats.reduce(0) { $0 + Int($1.minutesPlayed) }
    }
    
    private var sortedPlayers: [Player] {
        (team.playersArray).sorted { player1, player2 in
            let stats1 = getPlayerStats(for: player1)
            let stats2 = getPlayerStats(for: player2)
            return stats1.totalMinutes > stats2.totalMinutes
        }
    }
    
    private var playtimeData: [PlaytimeDataPoint] {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow, .indigo]
        
        return sortedPlayers.enumerated().map { index, player in
            let stats = getPlayerStats(for: player)
            return PlaytimeDataPoint(
                id: player.objectID,
                name: player.name ?? "Unknown",
                minutes: stats.totalMinutes,
                color: colors[index % colors.count]
            )
        }
    }
    
    private func getPlayerStats(for player: Player) -> PlayerStatsSummary {
        let playerFilteredStats = filteredStats.filter { $0.player == player }
        
        return PlayerStatsSummary(
            totalMinutes: playerFilteredStats.reduce(0) { $0 + Int($1.minutesPlayed) },
            totalGoals: playerFilteredStats.reduce(0) { $0 + Int($1.goals) },
            totalAssists: playerFilteredStats.reduce(0) { $0 + Int($1.assists) },
            matchesPlayed: playerFilteredStats.count
        )
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(AppTheme.headerFont)
                .foregroundColor(AppTheme.primaryText)
            
            Text(title)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct PlayerStatsRow: View {
    let player: Player
    let stats: PlayerStatsSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // Player avatar placeholder
            Circle()
                .fill(AppTheme.accentColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name ?? "Unknown")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text(player.position ?? "")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                StatBadge(value: "\(stats.totalMinutes)", label: "min", color: .gray)
                StatBadge(value: "\(stats.totalGoals)", label: "G", color: AppTheme.accentColor)
                StatBadge(value: "\(stats.totalAssists)", label: "A", color: .blue)
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(minWidth: 30)
    }
}

// MARK: - Supporting Types

enum StatisticsTimeframe: String, CaseIterable {
    case allTime = "All Time"
    case lastMonth = "Last Month"
    case lastWeek = "Last Week"
    
    var displayName: String {
        self.rawValue
    }
}

struct PlayerStatsSummary {
    let totalMinutes: Int
    let totalGoals: Int
    let totalAssists: Int
    let matchesPlayed: Int
}

struct PlaytimeDataPoint: Identifiable {
    let id: NSManagedObjectID
    let name: String
    let minutes: Int
    let color: Color
}