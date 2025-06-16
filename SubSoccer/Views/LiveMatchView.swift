import SwiftUI
import CoreData

struct FieldPosition {
    let id = UUID()
    let position: CGPoint
    let name: String
    let isMainPosition: Bool
    
    init(x: Double, y: Double, name: String, isMainPosition: Bool = true) {
        self.position = CGPoint(x: x, y: y)
        self.name = name
        self.isMainPosition = isMainPosition
    }
}

class FieldPositions {
    static let positions: [FieldPosition] = [
        // Goalkeeper
        FieldPosition(x: 0.5, y: 0.95, name: "GK"),
        
        // Defense (4 defenders)
        FieldPosition(x: 0.2, y: 0.75, name: "LB"),
        FieldPosition(x: 0.4, y: 0.8, name: "CB"),
        FieldPosition(x: 0.6, y: 0.8, name: "CB"),
        FieldPosition(x: 0.8, y: 0.75, name: "RB"),
        
        // Midfield (3 midfielders)
        FieldPosition(x: 0.25, y: 0.55, name: "LM"),
        FieldPosition(x: 0.5, y: 0.6, name: "CM"),
        FieldPosition(x: 0.75, y: 0.55, name: "RM"),
        
        // Attack (3 forwards)
        FieldPosition(x: 0.3, y: 0.35, name: "LF"),
        FieldPosition(x: 0.5, y: 0.3, name: "CF"),
        FieldPosition(x: 0.7, y: 0.35, name: "RF")
    ]
}

struct SubstitutionEvent {
    let id = UUID()
    let timestamp: Date
    let playerOut: Player
    let playerIn: Player
    let minute: Int
}

struct LiveMatchView: View {
    let match: Match
    @Environment(\.dismiss) private var dismiss
    
    @State private var matchTimer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning: Bool = false
    @State private var playersOnField: [Player] = []
    @State private var playersOnBench: [Player] = []
    @State private var playerPositions: [UUID: FieldPosition] = [:]
    @State private var substitutionHistory: [SubstitutionEvent] = []
    @State private var playerPlaytimes: [UUID: TimeInterval] = [:]
    @State private var playerGoals: [UUID: Int] = [:]
    @State private var playerAssists: [UUID: Int] = [:]
    @State private var matchStarted = false
    @State private var showingGoalAssistSelector = false
    @State private var isSelectingGoal = true
    @State private var showingLineupSuggestions = false
    
    private var players: [Player] {
        (match.team?.playersArray ?? []).sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Soccer field
                        soccerFieldView(in: geometry)
                            .frame(height: geometry.size.height * 0.65)
                        
                        // Substitute players and controls
                        bottomControlsView
                            .frame(height: geometry.size.height * 0.35)
                    }
                }
            }
            
            // Goal/Assist selector overlay
            if showingGoalAssistSelector {
                goalAssistSelectorOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupInitialLineup()
        }
        .onDisappear {
            stopTimer()
        }
        .sheet(isPresented: $showingLineupSuggestions) {
            if let team = match.team {
                LineupSuggestionView(team: team)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("Close") {
                dismiss()
            }
            .foregroundColor(AppTheme.primaryText)
            .font(AppTheme.bodyFont)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(match.team?.name ?? "Match")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("\(playersOnField.count) on field")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            Button(action: {
                showingLineupSuggestions = true
            }) {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(AppTheme.accentColor)
            }
            
            VStack(spacing: 8) {
                Text(formattedTime)
                    .font(AppTheme.headerFont.monospaced())
                    .foregroundColor(AppTheme.accentColor)
                
                HStack(spacing: 12) {
                    timerButton(icon: "play.fill", action: startTimer)
                        .opacity(isRunning ? 0.5 : 1.0)
                        .disabled(isRunning)
                    
                    timerButton(icon: "pause.fill", action: pauseTimer)
                        .opacity(!isRunning ? 0.5 : 1.0)
                        .disabled(!isRunning)
                    
                    timerButton(icon: "stop.fill", action: resetTimer)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
    }
    
    private func timerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.primaryText)
                .frame(width: 24, height: 24)
                .background(AppTheme.accentColor.opacity(0.2))
                .clipShape(Circle())
        }
    }
    
    private func soccerFieldView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Field background
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Field markings
            fieldMarkingsView
            
            // Position spots
            ForEach(FieldPositions.positions, id: \.id) { fieldPosition in
                positionSpotView(fieldPosition: fieldPosition)
                    .position(
                        x: fieldPosition.position.x * geometry.size.width,
                        y: fieldPosition.position.y * geometry.size.height
                    )
            }
            
            // Players on field in their assigned positions
            ForEach(playersOnField, id: \.objectID) { player in
                if let position = playerPositions[player.id ?? UUID()] {
                    playerTokenView(player: player, isOnField: true)
                        .position(
                            x: position.position.x * geometry.size.width,
                            y: position.position.y * geometry.size.height
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
        )
    }
    
    private var fieldMarkingsView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Boundary lines
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                
                // Center line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height / 2))
                    path.addLine(to: CGPoint(x: width, y: height / 2))
                }
                .stroke(Color.white, lineWidth: 2)
                
                // Center circle
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: min(width, height) * 0.3)
                    .position(x: width / 2, y: height / 2)
                
                // Penalty areas
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: width * 0.4, height: height * 0.2)
                    .position(x: width / 2, y: height * 0.1)
                
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: width * 0.4, height: height * 0.2)
                    .position(x: width / 2, y: height * 0.9)
                
                // Goals
                Rectangle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: width * 0.2, height: 8)
                    .position(x: width / 2, y: 0)
                
                Rectangle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: width * 0.2, height: 8)
                    .position(x: width / 2, y: height)
            }
        }
    }
    
    private func playerTokenView(player: Player, isOnField: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isOnField ? AppTheme.accentColor : AppTheme.secondaryBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            
            Text("\(player.jerseyNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isOnField ? .black : AppTheme.primaryText)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Goal and Assist tracking buttons
            HStack(spacing: 16) {
                actionButton(
                    title: "Goal",
                    icon: "soccer.ball",
                    action: { showGoalAssistSelector(isGoal: true) }
                )
                
                actionButton(
                    title: "Assist",
                    icon: "hand.thumbsup",
                    action: { showGoalAssistSelector(isGoal: false) }
                )
            }
            
            // Substitute players section
            substitutePlayersView
        }
        .padding()
        .background(AppTheme.secondaryBackground)
    }
    
    private func positionSpotView(fieldPosition: FieldPosition) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
            
            Text(fieldPosition.name)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(AppTheme.accentColor)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryBackground)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var substitutePlayersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Substitutes (\(playersOnBench.count))")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(playersOnBench, id: \.objectID) { player in
                        VStack(spacing: 8) {
                            playerTokenView(player: player, isOnField: false)
                                .onTapGesture {
                                    handleSubstitutePlayerTap(player)
                                }
                            
                            VStack(spacing: 2) {
                                Text(player.name ?? "Unknown")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.primaryText)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "soccer.ball")
                                            .font(.caption2)
                                        Text("\(playerGoals[player.id ?? UUID(), default: 0])")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(AppTheme.accentColor)
                                    
                                    HStack(spacing: 2) {
                                        Image(systemName: "hand.thumbsup")
                                            .font(.caption2)
                                        Text("\(playerAssists[player.id ?? UUID(), default: 0])")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(AppTheme.accentColor)
                                }
                            }
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    
    private var goalAssistSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    showingGoalAssistSelector = false
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.secondaryText)
                        .frame(width: 40, height: 4)
                    
                    Text(isSelectingGoal ? "Select Goal Scorer" : "Select Assist Provider")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(playersOnField, id: \.objectID) { player in
                                Button(action: {
                                    recordGoalOrAssist(for: player)
                                }) {
                                    HStack {
                                        playerTokenView(player: player, isOnField: true)
                                            .scaleEffect(0.8)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(player.name ?? "Unknown")
                                                .font(AppTheme.bodyFont)
                                                .foregroundColor(AppTheme.primaryText)
                                            
                                            Text("#\(player.jerseyNumber)")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.secondaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        if isSelectingGoal {
                                            Text("\(playerGoals[player.id ?? UUID(), default: 0])")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.accentColor)
                                        } else {
                                            Text("\(playerAssists[player.id ?? UUID(), default: 0])")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.primaryBackground)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 300)
                }
                .padding()
                .background(AppTheme.secondaryBackground)
                .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
            }
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: showingGoalAssistSelector)
    }
    
    private func substitutionHistoryRow(event: SubstitutionEvent) -> some View {
        HStack(spacing: 12) {
            Text("\(event.minute)'")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.accentColor)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(event.playerOut.name ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text(event.playerIn.name ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(AppTheme.primaryText)
                }
                
                Text(DateFormatter.timeFormatter.string(from: event.timestamp))
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.primaryBackground)
        .cornerRadius(8)
    }
    
    // MARK: - Timer Functions
    
    private func startTimer() {
        isRunning = true
        matchStarted = true
        matchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
            updatePlayerPlaytimes()
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        matchTimer?.invalidate()
        matchTimer = nil
    }
    
    private func resetTimer() {
        pauseTimer()
        elapsedTime = 0
        matchStarted = false
        saveMatchStatistics()
        resetPlayerStats()
    }
    
    private func stopTimer() {
        matchTimer?.invalidate()
        matchTimer = nil
    }
    
    
    // MARK: - Match Setup
    
    private func setupInitialLineup() {
        let allPlayers = Array(players)
        
        // Put first 11 players on field (or all if less than 11)
        let maxOnField = min(11, allPlayers.count)
        playersOnField = Array(allPlayers.prefix(maxOnField))
        playersOnBench = Array(allPlayers.dropFirst(maxOnField))
        
        // Assign positions to players on field
        assignPlayerPositions()
        
        // Initialize player statistics
        initializePlayerStats()
    }
    
    private func assignPlayerPositions() {
        let positions = FieldPositions.positions
        
        for (index, player) in playersOnField.enumerated() {
            if index < positions.count, let playerID = player.id {
                playerPositions[playerID] = positions[index]
            }
        }
    }
    
    // MARK: - Substitution Logic
    
    private func executeSubstitution(playerOut: Player, playerIn: Player) {
        // Transfer position from outgoing to incoming player
        if let playerOutID = playerOut.id,
           let playerInID = playerIn.id,
           let position = playerPositions[playerOutID] {
            playerPositions[playerInID] = position
            playerPositions.removeValue(forKey: playerOutID)
        }
        
        // Remove from field, add to bench
        if let outIndex = playersOnField.firstIndex(of: playerOut) {
            playersOnField.remove(at: outIndex)
        }
        playersOnBench.append(playerOut)
        
        // Remove from bench, add to field
        if let inIndex = playersOnBench.firstIndex(of: playerIn) {
            playersOnBench.remove(at: inIndex)
        }
        playersOnField.append(playerIn)
        
        // Record the substitution
        let event = SubstitutionEvent(
            timestamp: Date(),
            playerOut: playerOut,
            playerIn: playerIn,
            minute: Int(elapsedTime / 60)
        )
        substitutionHistory.append(event)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func handleSubstitutePlayerTap(_ player: Player) {
        // Quick substitution with random field player
        guard let randomFieldPlayer = playersOnField.randomElement() else { return }
        executeSubstitution(playerOut: randomFieldPlayer, playerIn: player)
    }
    
    
    // MARK: - Statistics Tracking
    
    private func updatePlayerPlaytimes() {
        for player in playersOnField {
            if let playerID = player.id {
                playerPlaytimes[playerID, default: 0] += 1
            }
        }
    }
    
    private func saveMatchStatistics() {
        guard matchStarted else { return }
        
        let context = PersistenceController.shared.container.viewContext
        
        for player in players {
            guard let playerID = player.id else { continue }
            
            let playerStats = PlayerStats(context: context)
            playerStats.id = UUID()
            playerStats.player = player
            playerStats.match = match
            playerStats.minutesPlayed = Int16(playerPlaytimes[playerID, default: 0] / 60)
            playerStats.goals = Int16(playerGoals[playerID, default: 0])
            playerStats.assists = Int16(playerAssists[playerID, default: 0])
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save match statistics: \(error)")
        }
    }
    
    private func resetPlayerStats() {
        playerPlaytimes.removeAll()
        playerGoals.removeAll()
        playerAssists.removeAll()
    }
    
    private func initializePlayerStats() {
        for player in players {
            if let playerID = player.id {
                playerPlaytimes[playerID] = 0
                playerGoals[playerID] = 0
                playerAssists[playerID] = 0
            }
        }
    }
    
    private func showGoalAssistSelector(isGoal: Bool) {
        isSelectingGoal = isGoal
        showingGoalAssistSelector = true
    }
    
    private func recordGoalOrAssist(for player: Player) {
        guard let playerID = player.id else { return }
        
        if isSelectingGoal {
            playerGoals[playerID, default: 0] += 1
        } else {
            playerAssists[playerID, default: 0] += 1
        }
        
        showingGoalAssistSelector = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Extensions

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}