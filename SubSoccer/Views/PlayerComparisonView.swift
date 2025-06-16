import SwiftUI
import Charts

struct PlayerComparisonView: View {
    let team: Team
    let selectedPlayer: Player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var comparisonPlayer: Player?
    @State private var showingPlayerSelector = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                if let comparisonPlayer = comparisonPlayer {
                    comparisonView(with: comparisonPlayer)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Player Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select Player") {
                        showingPlayerSelector = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
            .sheet(isPresented: $showingPlayerSelector) {
                PlayerSelectorView(team: team, excludedPlayer: selectedPlayer) { player in
                    comparisonPlayer = player
                    showingPlayerSelector = false
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.secondaryText)
            
            VStack(spacing: 8) {
                Text("Select Player to Compare")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Choose another player to compare stats with \(selectedPlayer.name ?? "Unknown")")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button("Select Player") {
                showingPlayerSelector = true
            }
            .font(AppTheme.bodyFont)
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.accentColor)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func comparisonView(with player: Player) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Player headers
                playerHeadersView(player)
                
                // Comparison charts
                comparisonChartsView(player)
                
                // Detailed stats comparison
                detailedStatsView(player)
            }
            .padding()
        }
    }
    
    private func playerHeadersView(_ comparisonPlayer: Player) -> some View {
        HStack(spacing: 16) {
            // Selected player
            PlayerHeaderCard(
                player: selectedPlayer,
                stats: getPlayerStats(for: selectedPlayer),
                isHighlighted: true
            )
            
            Text("VS")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.accentColor)
                .frame(width: 40)
            
            // Comparison player
            PlayerHeaderCard(
                player: comparisonPlayer,
                stats: getPlayerStats(for: comparisonPlayer),
                isHighlighted: false
            )
        }
    }
    
    private func comparisonChartsView(_ comparisonPlayer: Player) -> some View {
        VStack(spacing: 24) {
            // Goals comparison
            comparisonChart(
                title: "Goals Comparison",
                selectedValue: getPlayerStats(for: selectedPlayer).totalGoals,
                comparisonValue: getPlayerStats(for: comparisonPlayer).totalGoals,
                color: AppTheme.accentColor,
                icon: "soccer.ball"
            )
            
            // Assists comparison
            comparisonChart(
                title: "Assists Comparison",
                selectedValue: getPlayerStats(for: selectedPlayer).totalAssists,
                comparisonValue: getPlayerStats(for: comparisonPlayer).totalAssists,
                color: .blue,
                icon: "hand.thumbsup"
            )
            
            // Playtime comparison
            comparisonChart(
                title: "Playtime Comparison (Minutes)",
                selectedValue: getPlayerStats(for: selectedPlayer).totalMinutes,
                comparisonValue: getPlayerStats(for: comparisonPlayer).totalMinutes,
                color: .orange,
                icon: "clock"
            )
        }
    }
    
    private func comparisonChart(
        title: String,
        selectedValue: Int,
        comparisonValue: Int,
        color: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
            }
            
            Chart {
                BarMark(
                    x: .value("Player", selectedPlayer.name ?? "Unknown"),
                    y: .value("Value", selectedValue)
                )
                .foregroundStyle(AppTheme.accentColor)
                .cornerRadius(4)
                
                BarMark(
                    x: .value("Player", comparisonPlayer?.name ?? "Unknown"),
                    y: .value("Value", comparisonValue)
                )
                .foregroundStyle(color.opacity(0.7))
                .cornerRadius(4)
            }
            .frame(height: 100)
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
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func detailedStatsView(_ comparisonPlayer: Player) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Comparison")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            let selectedStats = getPlayerStats(for: selectedPlayer)
            let comparisonStats = getPlayerStats(for: comparisonPlayer)
            
            VStack(spacing: 12) {
                ComparisonRow(
                    title: "Matches Played",
                    selectedValue: "\(selectedStats.matchesPlayed)",
                    comparisonValue: "\(comparisonStats.matchesPlayed)",
                    selectedPlayerName: selectedPlayer.name ?? "Unknown",
                    comparisonPlayerName: comparisonPlayer.name ?? "Unknown"
                )
                
                ComparisonRow(
                    title: "Goals per Match",
                    selectedValue: String(format: "%.1f", selectedStats.matchesPlayed > 0 ? Double(selectedStats.totalGoals) / Double(selectedStats.matchesPlayed) : 0),
                    comparisonValue: String(format: "%.1f", comparisonStats.matchesPlayed > 0 ? Double(comparisonStats.totalGoals) / Double(comparisonStats.matchesPlayed) : 0),
                    selectedPlayerName: selectedPlayer.name ?? "Unknown",
                    comparisonPlayerName: comparisonPlayer.name ?? "Unknown"
                )
                
                ComparisonRow(
                    title: "Assists per Match",
                    selectedValue: String(format: "%.1f", selectedStats.matchesPlayed > 0 ? Double(selectedStats.totalAssists) / Double(selectedStats.matchesPlayed) : 0),
                    comparisonValue: String(format: "%.1f", comparisonStats.matchesPlayed > 0 ? Double(comparisonStats.totalAssists) / Double(comparisonStats.matchesPlayed) : 0),
                    selectedPlayerName: selectedPlayer.name ?? "Unknown",
                    comparisonPlayerName: comparisonPlayer.name ?? "Unknown"
                )
                
                ComparisonRow(
                    title: "Minutes per Match",
                    selectedValue: String(format: "%.0f", selectedStats.matchesPlayed > 0 ? Double(selectedStats.totalMinutes) / Double(selectedStats.matchesPlayed) : 0),
                    comparisonValue: String(format: "%.0f", comparisonStats.matchesPlayed > 0 ? Double(comparisonStats.totalMinutes) / Double(comparisonStats.matchesPlayed) : 0),
                    selectedPlayerName: selectedPlayer.name ?? "Unknown",
                    comparisonPlayerName: comparisonPlayer.name ?? "Unknown"
                )
            }
        }
    }
    
    private func getPlayerStats(for player: Player) -> PlayerStatsSummary {
        let playerStats = player.statisticsArray
        
        return PlayerStatsSummary(
            totalMinutes: playerStats.reduce(0) { $0 + Int($1.minutesPlayed) },
            totalGoals: playerStats.reduce(0) { $0 + Int($1.goals) },
            totalAssists: playerStats.reduce(0) { $0 + Int($1.assists) },
            matchesPlayed: playerStats.count
        )
    }
}

// MARK: - Supporting Views

struct PlayerHeaderCard: View {
    let player: Player
    let stats: PlayerStatsSummary
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Player avatar
            Circle()
                .fill(isHighlighted ? AppTheme.accentColor : AppTheme.secondaryText)
                .frame(width: 60, height: 60)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.title2.bold())
                        .foregroundColor(isHighlighted ? .black : AppTheme.primaryText)
                )
            
            VStack(spacing: 4) {
                Text(player.name ?? "Unknown")
                    .font(AppTheme.bodyFont.bold())
                    .foregroundColor(AppTheme.primaryText)
                
                Text(player.position ?? "")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(stats.totalGoals)")
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.accentColor)
                        Text("Goals")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(stats.totalAssists)")
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                        Text("Assists")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                VStack(spacing: 2) {
                    Text("\(stats.totalMinutes)")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                    Text("Minutes")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? AppTheme.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct ComparisonRow: View {
    let title: String
    let selectedValue: String
    let comparisonValue: String
    let selectedPlayerName: String
    let comparisonPlayerName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
            
            HStack {
                // Selected player
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPlayerName)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Text(selectedValue)
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.accentColor)
                }
                
                Spacer()
                
                // Comparison player
                VStack(alignment: .trailing, spacing: 4) {
                    Text(comparisonPlayerName)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Text(comparisonValue)
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.primaryText)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

struct PlayerSelectorView: View {
    let team: Team
    let excludedPlayer: Player
    let onPlayerSelected: (Player) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var availablePlayers: [Player] {
        team.playersArray.filter { $0 != excludedPlayer }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availablePlayers, id: \.objectID) { player in
                            Button(action: {
                                onPlayerSelected(player)
                            }) {
                                HStack(spacing: 12) {
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
                    .padding()
                }
            }
            .navigationTitle("Select Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryText)
                }
            }
        }
    }
}

