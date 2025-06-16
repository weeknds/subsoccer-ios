import SwiftUI
import CoreData

struct FieldPosition: Equatable {
    let id = UUID()
    let position: CGPoint
    let name: String
    let isMainPosition: Bool
    
    init(x: Double, y: Double, name: String, isMainPosition: Bool = true) {
        self.position = CGPoint(x: x, y: y)
        self.name = name
        self.isMainPosition = isMainPosition
    }
    
    static func == (lhs: FieldPosition, rhs: FieldPosition) -> Bool {
        return lhs.id == rhs.id
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
    @State private var redCardedPlayers: Set<UUID> = []
    @State private var yellowCardedPlayers: [UUID: Int] = [:]  // Player ID -> Number of yellow cards
    @State private var matchStarted = false
    @State private var showingGoalAssistSelector = false
    @State private var isSelectingGoal = true
    @State private var showingLineupSuggestions = false
    @State private var selectedPlayerToSubstitute: Player?
    @State private var selectedFieldPosition: FieldPosition?
    @State private var substitutionsUsed: Int = 0
    @State private var currentHalf: Int = 1
    @State private var halfStartTime: TimeInterval = 0
    @State private var showingRedCardSelector = false
    @State private var showingYellowCardSelector = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
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
                    VStack(spacing: 8) {
                        // Soccer field
                        soccerFieldView(in: geometry)
                            .frame(height: geometry.size.height * 0.58)
                        
                        // Substitute players and controls
                        ScrollView {
                            bottomControlsView
                        }
                        .frame(height: geometry.size.height * 0.42)
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
        .alert("Match Alert", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
        .sheet(isPresented: $showingRedCardSelector) {
            redCardSelectorView
        }
        .sheet(isPresented: $showingYellowCardSelector) {
            yellowCardSelectorView
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
                
                VStack(spacing: 0) {
                    Text("\(playersOnField.count)/11 on field")
                        .font(AppTheme.captionFont)
                        .foregroundColor(playersOnField.count == 11 ? AppTheme.accentColor : AppTheme.secondaryText)
                    
                    Text("Half \(currentHalf) • \(substitutionsUsed)/5 subs")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
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
                    .onTapGesture {
                        handleFieldPositionTap(fieldPosition)
                    }
            }
            
            // Players on field in their assigned positions
            ForEach(playersOnField, id: \.objectID) { player in
                if let position = playerPositions[player.id ?? UUID()] {
                    playerTokenView(player: player, isOnField: true)
                        .position(
                            x: position.position.x * geometry.size.width,
                            y: position.position.y * geometry.size.height
                        )
                        .onTapGesture {
                            handleFieldPlayerTap(player)
                        }
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
        let playerID = player.id ?? UUID()
        let isRedCarded = redCardedPlayers.contains(playerID)
        let yellowCards = yellowCardedPlayers[playerID, default: 0]
        let hasYellowCard = yellowCards > 0
        
        return ZStack {
            Circle()
                .fill(isRedCarded ? Color.red : (isOnField ? AppTheme.accentColor : AppTheme.secondaryBackground))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(hasYellowCard && !isRedCarded ? Color.yellow : Color.white, lineWidth: hasYellowCard && !isRedCarded ? 3 : 2)
                )
            
            if isRedCarded {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            } else {
                VStack(spacing: 0) {
                    Text("\(player.jerseyNumber)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isOnField ? .black : AppTheme.primaryText)
                    
                    if yellowCards > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<min(yellowCards, 2), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.yellow)
                                    .frame(width: 3, height: 3)
                            }
                        }
                        .offset(y: -2)
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .opacity(isRedCarded ? 0.7 : 1.0)
    }
    
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Goal, Assist, and Card tracking buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton(
                        title: "Goal",
                        icon: "soccerball",
                        action: { showGoalAssistSelector(isGoal: true) }
                    )
                    
                    actionButton(
                        title: "Assist",
                        icon: "hand.thumbsup",
                        action: { showGoalAssistSelector(isGoal: false) }
                    )
                }
                
                HStack(spacing: 12) {
                    actionButton(
                        title: "Yellow Card",
                        icon: "rectangle.fill",
                        action: { showingYellowCardSelector = true },
                        color: .yellow
                    )
                    
                    actionButton(
                        title: "Red Card",
                        icon: "rectangle.fill",
                        action: { showingRedCardSelector = true },
                        color: .red
                    )
                }
            }
            
            // Substitute players section
            substitutePlayersView
        }
        .padding()
        .background(AppTheme.secondaryBackground)
    }
    
    private func positionSpotView(fieldPosition: FieldPosition) -> some View {
        let isOccupied = playersOnField.contains { player in
            playerPositions[player.id ?? UUID()] == fieldPosition
        }
        let isSelected = selectedFieldPosition == fieldPosition
        
        return ZStack {
            Circle()
                .fill(isOccupied ? Color.clear : (isSelected ? AppTheme.accentColor.opacity(0.5) : Color.white.opacity(0.3)))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(isSelected ? AppTheme.accentColor : Color.white, lineWidth: isSelected ? 2 : 1)
                )
            
            if !isOccupied {
                Text(fieldPosition.name)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isSelected ? .black : .white)
            }
        }
    }
    
    private func actionButton(title: String, icon: String, action: @escaping () -> Void, color: Color = AppTheme.accentColor) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                
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
                    .stroke(color.opacity(0.2), lineWidth: 1)
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
                                    handleSubstitutePlayerSelection(player)
                                }
                                .background(
                                    Circle()
                                        .stroke(selectedPlayerToSubstitute == player ? AppTheme.accentColor : Color.clear, lineWidth: 3)
                                        .frame(width: 50, height: 50)
                                )
                            
                            VStack(spacing: 2) {
                                Text(player.name ?? "Unknown")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.primaryText)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "soccerball")
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
        // Validate match can start
        guard validateMatchStart() else { return }
        
        isRunning = true
        matchStarted = true
        
        // Set half start time if this is the beginning of a half
        if elapsedTime == 0 || isStartOfNewHalf() {
            halfStartTime = elapsedTime
        }
        
        matchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
            updatePlayerPlaytimes()
            checkHalfTime()
        }
    }
    
    private func validateMatchStart() -> Bool {
        // Must have at least 7 players on field
        guard playersOnField.count >= 7 else {
            showValidationError("Need at least 7 players on field to start match")
            return false
        }
        
        // Ideally should have 11 players
        if playersOnField.count < 11 {
            showValidationError("Warning: Starting with only \(playersOnField.count) players. Ideal is 11.")
        }
        
        return true
    }
    
    private func isStartOfNewHalf() -> Bool {
        let matchDuration = Double(match.duration * 60) // Convert to seconds
        let halfDuration = matchDuration / Double(match.numberOfHalves)
        let currentHalfTime = elapsedTime - halfStartTime
        return currentHalfTime >= halfDuration
    }
    
    private func checkHalfTime() {
        let matchDuration = Double(match.duration * 60) // Convert to seconds
        let halfDuration = matchDuration / Double(match.numberOfHalves)
        let currentHalfTime = elapsedTime - halfStartTime
        
        // Check if half is complete
        if currentHalfTime >= halfDuration && currentHalf < match.numberOfHalves {
            pauseTimer()
            currentHalf += 1
            halfStartTime = elapsedTime
            
            // Show half-time notification
            showValidationError("Half \(currentHalf - 1) completed. Ready for Half \(currentHalf)")
        }
        
        // Check if match is complete
        if currentHalf > match.numberOfHalves {
            resetTimer()
            showValidationError("Match completed!")
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
        let allPlayers = Array(players.filter { player in
            !redCardedPlayers.contains(player.id ?? UUID())
        })
        
        // Put first 11 players on field (or all if less than 11)
        let maxOnField = min(11, allPlayers.count)
        playersOnField = Array(allPlayers.prefix(maxOnField))
        playersOnBench = Array(allPlayers.dropFirst(maxOnField))
        
        // Assign positions to players on field
        assignPlayerPositions()
        
        // Initialize player statistics
        initializePlayerStats()
        
        // Reset match state
        substitutionsUsed = 0
        currentHalf = 1
        halfStartTime = 0
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
        // Validate substitution rules
        guard validateSubstitution(playerOut: playerOut, playerIn: playerIn) else { return }
        
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
        substitutionsUsed += 1
        
        // Clear selection
        selectedPlayerToSubstitute = nil
        selectedFieldPosition = nil
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func handleSubstitutePlayerSelection(_ player: Player) {
        // Validate player is eligible for substitution
        guard !redCardedPlayers.contains(player.id ?? UUID()) else {
            showValidationError("Player is sent off and cannot be substituted")
            return
        }
        
        selectedPlayerToSubstitute = player
        selectedFieldPosition = nil
    }
    
    private func handleFieldPlayerTap(_ player: Player) {
        // If we have a substitute selected, execute substitution
        if let substitute = selectedPlayerToSubstitute {
            executeSubstitution(playerOut: player, playerIn: substitute)
        }
    }
    
    private func handleFieldPositionTap(_ position: FieldPosition) {
        // Only allow tapping empty positions
        let isOccupied = playersOnField.contains { player in
            playerPositions[player.id ?? UUID()] == position
        }
        
        guard !isOccupied else { return }
        
        if let substitute = selectedPlayerToSubstitute {
            // Move substitute to selected position
            movePlayerToPosition(substitute, to: position)
        } else {
            selectedFieldPosition = position
        }
    }
    
    private func movePlayerToPosition(_ player: Player, to position: FieldPosition) {
        guard let playerID = player.id else { return }
        
        // Validate we can add player to field
        guard validatePlayerAddition(player) else { return }
        
        // Remove from bench, add to field
        if let inIndex = playersOnBench.firstIndex(of: player) {
            playersOnBench.remove(at: inIndex)
        }
        playersOnField.append(player)
        playerPositions[playerID] = position
        
        // Clear selection
        selectedPlayerToSubstitute = nil
        selectedFieldPosition = nil
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func validateSubstitution(playerOut: Player, playerIn: Player) -> Bool {
        // Check substitution limit (5 per match)
        guard substitutionsUsed < 5 else {
            showValidationError("Maximum 5 substitutions allowed per match")
            return false
        }
        
        // Check if player being substituted in is red carded
        guard !redCardedPlayers.contains(playerIn.id ?? UUID()) else {
            showValidationError("Cannot substitute red-carded player")
            return false
        }
        
        // Check if player is already on field
        guard !playersOnField.contains(playerIn) else {
            showValidationError("Player is already on the field")
            return false
        }
        
        return true
    }
    
    private func validatePlayerAddition(_ player: Player) -> Bool {
        // Check if field is full (11 players max)
        guard playersOnField.count < 11 else {
            showValidationError("Field is full (11 players maximum)")
            return false
        }
        
        // Check if player is red carded
        guard !redCardedPlayers.contains(player.id ?? UUID()) else {
            showValidationError("Cannot add red-carded player to field")
            return false
        }
        
        return true
    }
    
    private func validateMatchCanContinue() -> Bool {
        // Match cannot continue with fewer than 7 players
        let availablePlayers = playersOnField.count
        return availablePlayers >= 7
    }
    
    private func showValidationError(_ message: String) {
        validationMessage = message
        showingValidationAlert = true
        
        // Haptic feedback for error
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Red Card System
    
    private func giveRedCard(to player: Player) {
        guard let playerID = player.id else { return }
        
        // Add to red carded players
        redCardedPlayers.insert(playerID)
        
        // Remove from field if on field
        if let fieldIndex = playersOnField.firstIndex(of: player) {
            playersOnField.remove(at: fieldIndex)
            playerPositions.removeValue(forKey: playerID)
        }
        
        // Remove from bench if on bench
        if let benchIndex = playersOnBench.firstIndex(of: player) {
            playersOnBench.remove(at: benchIndex)
        }
        
        // Check if match can continue
        if !validateMatchCanContinue() {
            pauseTimer()
            showValidationError("Match cannot continue - team has fewer than 7 players")
        }
        
        showingRedCardSelector = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Yellow Card System
    
    private func giveYellowCard(to player: Player) {
        guard let playerID = player.id else { return }
        
        // Increment yellow card count
        yellowCardedPlayers[playerID, default: 0] += 1
        
        // Check for second yellow card (= red card)
        if yellowCardedPlayers[playerID, default: 0] >= 2 {
            // Convert to red card
            giveRedCard(to: player)
            return
        }
        
        showingYellowCardSelector = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private var redCardSelectorView: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Select Player for Red Card")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(playersOnField + playersOnBench, id: \.objectID) { player in
                                Button(action: {
                                    giveRedCard(to: player)
                                }) {
                                    HStack {
                                        playerTokenView(player: player, isOnField: playersOnField.contains(player))
                                            .scaleEffect(0.8)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(player.name ?? "Unknown")
                                                .font(AppTheme.bodyFont)
                                                .foregroundColor(AppTheme.primaryText)
                                            
                                            Text("#\(player.jerseyNumber) - \(playersOnField.contains(player) ? "On Field" : "On Bench")")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.secondaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "rectangle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.secondaryBackground)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Red Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingRedCardSelector = false
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }
    
    private var yellowCardSelectorView: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Select Player for Yellow Card")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(playersOnField + playersOnBench, id: \.objectID) { player in
                                Button(action: {
                                    giveYellowCard(to: player)
                                }) {
                                    HStack {
                                        playerTokenView(player: player, isOnField: playersOnField.contains(player))
                                            .scaleEffect(0.8)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(player.name ?? "Unknown")
                                                .font(AppTheme.bodyFont)
                                                .foregroundColor(AppTheme.primaryText)
                                            
                                            HStack {
                                                let playerLocation = playersOnField.contains(player) ? "On Field" : "On Bench"
                                                Text("#\(player.jerseyNumber) - \(playerLocation)")
                                                    .font(.caption)
                                                    .foregroundColor(AppTheme.secondaryText)
                                                
                                                if let playerID = player.id,
                                                   let yellowCards = yellowCardedPlayers[playerID],
                                                   yellowCards > 0 {
                                                    let cardText = yellowCards > 1 ? "s" : ""
                                                    Text("(\(yellowCards) yellow\(cardText))")
                                                        .font(.caption)
                                                        .foregroundColor(.yellow)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "rectangle.fill")
                                            .foregroundColor(.yellow)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.secondaryBackground)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Yellow Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingYellowCardSelector = false
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
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