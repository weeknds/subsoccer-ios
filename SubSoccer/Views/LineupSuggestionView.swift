import SwiftUI
import CoreData

struct LineupSuggestionView: View {
    let team: Team
    @Environment(\.dismiss) private var dismiss
    @StateObject private var suggestionService = LineupSuggestionService.shared
    
    @State private var selectedFormation: Formation = .fourFourTwo
    @State private var selectedMatchType: MatchType = .regular
    @State private var considerPlaytime = true
    @State private var considerPerformance = false
    @State private var playersOnField = 11
    @State private var currentSuggestion: LineupSuggestion?
    @State private var isGenerating = false
    @State private var showingFormationRecommendations = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Configuration Section
                        configurationSection
                        
                        // Generate Button
                        generateButton
                        
                        // Suggestion Results
                        if let suggestion = currentSuggestion {
                            suggestionResultsSection(suggestion)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Lineup Suggestions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Formations") {
                        showingFormationRecommendations = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
        .sheet(isPresented: $showingFormationRecommendations) {
            FormationRecommendationsView(team: team, selectedMatchType: selectedMatchType) { formation in
                selectedFormation = formation
                showingFormationRecommendations = false
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.accentColor)
            
            Text("AI Lineup Assistant")
                .font(AppTheme.headerFont)
                .foregroundColor(AppTheme.primaryText)
            
            Text("Get intelligent lineup suggestions based on player performance, playtime balance, and formation preferences.")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(16)
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            // Formation Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Formation")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Picker("Formation", selection: $selectedFormation) {
                    ForEach(Formation.allCases, id: \.self) { formation in
                        Text(formation.displayName)
                            .tag(formation)
                    }
                }
                .pickerStyle(.segmented)
                .colorMultiply(AppTheme.accentColor)
            }
            
            // Match Type Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Match Type")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Picker("Match Type", selection: $selectedMatchType) {
                    ForEach(MatchType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(AppTheme.primaryText)
            }
            
            // Players on Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Players on Field: \(playersOnField)")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Slider(value: Binding(
                    get: { Double(playersOnField) },
                    set: { playersOnField = Int($0) }
                ), in: 7...11, step: 1)
                .tint(AppTheme.accentColor)
            }
            
            // Considerations
            VStack(alignment: .leading, spacing: 12) {
                Text("Considerations")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Toggle("Balance Playtime", isOn: $considerPlaytime)
                    .tint(AppTheme.accentColor)
                    .foregroundColor(AppTheme.primaryText)
                
                Toggle("Consider Performance", isOn: $considerPerformance)
                    .tint(AppTheme.accentColor)
                    .foregroundColor(AppTheme.primaryText)
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private var generateButton: some View {
        Button(action: generateSuggestion) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.headline)
                }
                
                Text(isGenerating ? "Generating..." : "Generate Lineup")
                    .font(AppTheme.bodyFont.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.accentColor)
            .cornerRadius(12)
        }
        .disabled(isGenerating)
    }
    
    @ViewBuilder
    private func suggestionResultsSection(_ suggestion: LineupSuggestion) -> some View {
        VStack(spacing: 20) {
            // Results Header
            HStack {
                Text("Lineup Suggestion")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                BalanceScoreView(score: suggestion.balanceScore)
            }
            
            // Formation Visualization
            FormationVisualizationView(suggestion: suggestion)
            
            // Reasoning
            reasoningSection(suggestion.reasoning)
            
            // Lineup Details
            lineupDetailsSection(suggestion)
            
            // Bench Players
            benchPlayersSection(suggestion.bench)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func reasoningSection(_ reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Reasoning")
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            Text(reasoning)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.primaryBackground.opacity(0.5))
        .cornerRadius(8)
    }
    
    private func lineupDetailsSection(_ suggestion: LineupSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starting Lineup")
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(suggestion.lineup.indices, id: \.self) { index in
                    let playerPos = suggestion.lineup[index]
                    PlayerLineupCard(playerPosition: playerPos)
                }
            }
        }
    }
    
    private func benchPlayersSection(_ benchPlayers: [Player]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bench Players")
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            if benchPlayers.isEmpty {
                Text("No bench players")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(benchPlayers, id: \.objectID) { player in
                        BenchPlayerCard(player: player)
                    }
                }
            }
        }
    }
    
    private func generateSuggestion() {
        isGenerating = true
        
        // Simulate AI processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            currentSuggestion = suggestionService.generateBalancedLineup(
                for: team,
                playersOnField: playersOnField,
                considerPlaytime: considerPlaytime,
                considerPerformance: considerPerformance,
                formation: selectedFormation
            )
            isGenerating = false
        }
    }
}

// MARK: - Supporting Views

struct BalanceScoreView: View {
    let score: Double
    
    private var scoreColor: Color {
        switch score {
        case 8...10: return .green
        case 6..<8: return .yellow
        case 4..<6: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Balance Score:")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.secondaryText)
            
            Text(String(format: "%.1f/10", score))
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(scoreColor)
            
            Circle()
                .fill(scoreColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(scoreColor.opacity(0.1))
        .cornerRadius(16)
    }
}

struct FormationVisualizationView: View {
    let suggestion: LineupSuggestion
    
    var body: some View {
        VStack(spacing: 12) {
            Text(suggestion.formation.displayName)
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            ZStack {
                // Soccer field background
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: 200)
                
                // Field markings
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(height: 1)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(height: 1)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(height: 1)
                }
                .padding(.vertical, 20)
                
                // Player positions
                ForEach(suggestion.lineup.indices, id: \.self) { index in
                    let playerPos = suggestion.lineup[index]
                    PlayerToken(playerPosition: playerPos)
                        .position(
                            x: playerPos.x * 300,
                            y: (1 - playerPos.y) * 200
                        )
                }
            }
            .frame(height: 200)
            .clipped()
        }
    }
}

struct PlayerToken: View {
    let playerPosition: LineupPlayerPosition
    
    private var tokenColor: Color {
        switch playerPosition.position {
        case .goalkeeper: return .yellow
        case .defender: return .blue
        case .midfielder: return .green
        case .forward: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(tokenColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(playerPosition.player.jerseyNumber)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                )
            
            Text(playerPosition.player.name?.prefix(8) ?? "")
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

struct PlayerLineupCard: View {
    let playerPosition: LineupPlayerPosition
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.accentColor.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(playerPosition.player.jerseyNumber)")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playerPosition.player.name ?? "Unknown")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(1)
                
                Text(playerPosition.position.displayName)
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
        }
        .padding(8)
        .background(AppTheme.primaryBackground.opacity(0.5))
        .cornerRadius(8)
    }
}

struct BenchPlayerCard: View {
    let player: Player
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(AppTheme.secondaryText.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            Text(player.name?.prefix(6) ?? "")
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(6)
        .background(AppTheme.primaryBackground.opacity(0.3))
        .cornerRadius(6)
    }
}

struct FormationRecommendationsView: View {
    let team: Team
    let selectedMatchType: MatchType
    let onFormationSelected: (Formation) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var suggestionService = LineupSuggestionService.shared
    
    private var recommendedFormations: [Formation] {
        suggestionService.recommendFormation(for: team, matchType: selectedMatchType)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Based on your team composition and match type, here are the recommended formations:")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        ForEach(recommendedFormations, id: \.self) { formation in
                            FormationRecommendationCard(
                                formation: formation,
                                matchType: selectedMatchType
                            ) {
                                onFormationSelected(formation)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Formation Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
    }
}

struct FormationRecommendationCard: View {
    let formation: Formation
    let matchType: MatchType
    let onSelected: () -> Void
    
    var body: some View {
        Button(action: onSelected) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(formation.displayName)
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.accentColor)
                }
                
                Text(getFormationDescription(formation))
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    ForEach(["GK", "DEF", "MID", "FWD"], id: \.self) { position in
                        if let fieldPosition = LineupFieldPosition(rawValue: position),
                           let count = formation.positionRequirements[fieldPosition] {
                            Text("\(position): \(count)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentColor.opacity(0.2))
                                .cornerRadius(4)
                                .foregroundColor(AppTheme.primaryText)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
        }
    }
    
    private func getFormationDescription(_ formation: Formation) -> String {
        switch formation {
        case .fourFourTwo:
            return "Balanced formation with solid defense and midfield. Good for all-around play."
        case .fourThreeThree:
            return "Attacking formation with wide forwards. Ideal for possession and attacking play."
        case .threeFiveTwo:
            return "Midfield-heavy formation. Excellent for controlling the game through the center."
        case .threeFourThree:
            return "Attacking formation with wing-backs. High intensity and attacking pressure."
        case .fiveThreeTwo:
            return "Defensive formation with strong backline. Good for protecting leads and counter-attacks."
        }
    }
}