import SwiftUI
import CoreData
import PhotosUI

struct PlayerManagementView: View {
    let team: Team
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var optimizationService = DataOptimizationService.shared
    
    @State private var showingAddPlayer = false
    @State private var selectedPlayer: Player?
    @State private var searchText = ""
    @State private var showingInjuryManagement = false
    
    // Lazy loading state
    @State private var players: [Player] = []
    @State private var isLoading = false
    @State private var hasMorePlayers = true
    @State private var currentOffset = 0
    private let pageSize = 20
    
    var filteredPlayers: [Player] {
        return players
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    SearchBar(text: $searchText)
                        .padding(.horizontal, AppTheme.largePadding)
                        .padding(.top, AppTheme.standardPadding)
                    
                    if isLoading && players.isEmpty {
                        ProgressView("Loading players...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(AppTheme.secondaryText)
                    } else if filteredPlayers.isEmpty {
                        EmptyPlayersView(hasPlayers: !players.isEmpty)
                    } else {
                        OptimizedPlayersListView(
                            players: filteredPlayers,
                            selectedPlayer: $selectedPlayer,
                            isLoading: $isLoading,
                            hasMorePlayers: hasMorePlayers,
                            onLoadMore: loadMorePlayers
                        )
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton {
                            showingAddPlayer = true
                        }
                        .padding(.trailing, AppTheme.largePadding)
                        .padding(.bottom, AppTheme.largePadding)
                    }
                }
            }
            .navigationTitle(LocalizationKeys.playersTitle.localized(with: team.name ?? LocalizationKeys.teams.localized))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingInjuryManagement = true
                    }) {
                        Image(systemName: "bandage")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                AddEditPlayerView(team: team)
            }
            .sheet(item: $selectedPlayer) { player in
                PlayerDetailView(player: player, team: team)
            }
            .sheet(isPresented: $showingInjuryManagement) {
                InjuryManagementView(team: team)
            }
            .task {
                await loadInitialPlayers()
            }
            .onChange(of: searchText) { _, newValue in
                Task {
                    await searchPlayers(searchText: newValue)
                }
            }
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadInitialPlayers() async {
        isLoading = true
        currentOffset = 0
        hasMorePlayers = true
        
        let newPlayers = await optimizationService.fetchPaginatedPlayers(
            for: team,
            searchText: searchText,
            offset: 0,
            limit: pageSize
        )
        
        await MainActor.run {
            players = newPlayers
            currentOffset = pageSize
            hasMorePlayers = newPlayers.count == pageSize
            isLoading = false
        }
    }
    
    private func loadMorePlayers() {
        guard !isLoading && hasMorePlayers else { return }
        
        Task {
            isLoading = true
            
            let newPlayers = await optimizationService.fetchPaginatedPlayers(
                for: team,
                searchText: searchText,
                offset: currentOffset,
                limit: pageSize
            )
            
            await MainActor.run {
                players.append(contentsOf: newPlayers)
                currentOffset += pageSize
                hasMorePlayers = newPlayers.count == pageSize
                isLoading = false
            }
        }
    }
    
    private func searchPlayers(searchText: String) async {
        isLoading = true
        currentOffset = 0
        hasMorePlayers = true
        
        // Add a small delay to avoid too many requests while typing
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        let newPlayers = await optimizationService.fetchPaginatedPlayers(
            for: team,
            searchText: searchText,
            offset: 0,
            limit: pageSize * 2 // Load more for search results
        )
        
        await MainActor.run {
            players = newPlayers
            currentOffset = pageSize * 2
            hasMorePlayers = newPlayers.count == pageSize * 2
            isLoading = false
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.secondaryText)
                .font(.system(size: 16))
            
            TextField(LocalizationKeys.searchPlayersPlaceholder.localized, text: $text)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.secondaryText)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(AppTheme.standardPadding)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
    }
}

struct EmptyPlayersView: View {
    let hasPlayers: Bool
    
    var body: some View {
        VStack {
            Image(systemName: hasPlayers ? "magnifyingglass" : "person.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.accentColor)
                .padding(.bottom, 20)
            
            Text(hasPlayers ? LocalizationKeys.noPlayersFound.localized : LocalizationKeys.noPlayersYet.localized)
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 8)
            
            Text(hasPlayers ? LocalizationKeys.searchAdjustment.localized : LocalizationKeys.noPlayersDescription.localized)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OptimizedPlayersListView: View {
    let players: [Player]
    @Binding var selectedPlayer: Player?
    @Binding var isLoading: Bool
    let hasMorePlayers: Bool
    let onLoadMore: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var optimizationService = DataOptimizationService.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.standardPadding) {
                ForEach(Array(players.enumerated()), id: \.element) { index, player in
                    OptimizedPlayerCard(player: player) {
                        selectedPlayer = player
                    }
                    .contextMenu {
                        Button("Edit Player") {
                            selectedPlayer = player
                        }
                        Button("Delete Player", role: .destructive) {
                            deletePlayer(player)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            deletePlayer(player)
                        }
                        Button("Edit") {
                            selectedPlayer = player
                        }
                        .tint(AppTheme.accentColor)
                    }
                    .onAppear {
                        // Load more when approaching the end
                        if index == players.count - 3 && hasMorePlayers && !isLoading {
                            onLoadMore()
                        }
                    }
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more players...")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding()
                }
            }
            .padding(.horizontal, AppTheme.largePadding)
            .padding(.top, AppTheme.standardPadding)
            .padding(.bottom, 80) // Space for FAB
        }
    }
    
    private func deletePlayer(_ player: Player) {
        withAnimation {
            viewContext.delete(player)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting player: \(error)")
            }
        }
    }
}

struct OptimizedPlayerCard: View {
    let player: Player
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.largePadding) {
                OptimizedPlayerAvatar(player: player, size: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name ?? LocalizationKeys.unnamedPlayer.localized)
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)
                    
                    HStack {
                        Text("#\(player.jerseyNumber)")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.accentColor)
                            .fontWeight(.semibold)
                        
                        Text("•")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text(player.position ?? "No Position")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        if player.isInjured {
                            Image(systemName: "bandage")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(AppTheme.largePadding)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OptimizedPlayerAvatar: View {
    let player: Player
    let size: CGFloat
    
    @StateObject private var optimizationService = DataOptimizationService.shared
    @State private var image: UIImage?
    
    private var cacheKey: String {
        player.objectID.uriRepresentation().absoluteString
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.secondaryBackground)
        .clipShape(Circle())
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let imageData = player.profileImageData else { return }
        
        let targetSize = CGSize(width: size * 2, height: size * 2) // 2x for retina
        let loadedImage = optimizationService.loadOptimizedImage(
            from: imageData,
            cacheKey: cacheKey,
            targetSize: targetSize
        )
        
        await MainActor.run {
            image = loadedImage
        }
    }
}

// Keep the original PlayerAvatar for compatibility
struct PlayerAvatar: View {
    let player: Player
    let size: CGFloat
    
    var body: some View {
        OptimizedPlayerAvatar(player: player, size: size)
    }
}

struct AddEditPlayerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let team: Team
    let player: Player?
    
    @State private var playerName = ""
    @State private var jerseyNumber = 1
    @State private var selectedPosition = PlayerPosition.midfielder
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    
    init(team: Team, player: Player? = nil) {
        self.team = team
        self.player = player
        self._playerName = State(initialValue: player?.name ?? "")
        self._jerseyNumber = State(initialValue: Int(player?.jerseyNumber ?? 1))
        self._selectedPosition = State(initialValue: PlayerPosition(rawValue: player?.position ?? "") ?? .midfielder)
        self._profileImageData = State(initialValue: player?.profileImageData)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.largePadding) {
                        PhotoPickerSection(
                            selectedPhoto: $selectedPhoto,
                            profileImageData: $profileImageData
                        )
                        
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Player Name")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            TextField("Enter player name", text: $playerName)
                                .textFieldStyle(AppTextFieldStyle())
                        }
                        
                        HStack(spacing: AppTheme.largePadding) {
                            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                                Text("Jersey Number")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.primaryText)
                                
                                JerseyNumberPicker(number: $jerseyNumber)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                                Text("Position")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.primaryText)
                                
                                PositionPicker(position: $selectedPosition)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(AppTheme.largePadding)
                }
            }
            .navigationTitle(player == nil ? "New Player" : "Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlayer()
                    }
                    .foregroundColor(AppTheme.accentColor)
                    .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                Task {
                    if let data = try? await newPhoto?.loadTransferable(type: Data.self) {
                        // Compress image data before storing
                        profileImageData = DataOptimizationService.shared.compressImageData(data)
                    }
                }
            }
        }
    }
    
    private func savePlayer() {
        let playerToSave = player ?? Player(context: viewContext)
        playerToSave.name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        playerToSave.jerseyNumber = Int16(jerseyNumber)
        playerToSave.position = selectedPosition.rawValue
        playerToSave.profileImageData = profileImageData
        
        if player == nil {
            playerToSave.id = UUID()
            playerToSave.team = team
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving player: \(error)")
        }
    }
}

struct PhotoPickerSection: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var profileImageData: Data?
    
    @StateObject private var optimizationService = DataOptimizationService.shared
    @State private var displayImage: UIImage?
    
    var body: some View {
        VStack(spacing: AppTheme.standardPadding) {
            Group {
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .frame(width: 100, height: 100)
            .background(AppTheme.secondaryBackground)
            .clipShape(Circle())
            .onChange(of: profileImageData) { _, newData in
                updateDisplayImage(from: newData)
            }
            .onAppear {
                updateDisplayImage(from: profileImageData)
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text(profileImageData == nil ? "Add Photo" : "Change Photo")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.accentColor)
                    .padding(.horizontal, AppTheme.largePadding)
                    .padding(.vertical, AppTheme.standardPadding)
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
            }
        }
    }
    
    private func updateDisplayImage(from data: Data?) {
        guard let data = data else {
            displayImage = nil
            return
        }
        
        let targetSize = CGSize(width: 200, height: 200)
        displayImage = optimizationService.loadOptimizedImage(
            from: data,
            cacheKey: "photo_picker_\(data.hashValue)",
            targetSize: targetSize
        )
    }
}

struct JerseyNumberPicker: View {
    @Binding var number: Int
    
    var body: some View {
        Menu {
            ForEach(1...99, id: \.self) { num in
                Button("\(num)") {
                    number = num
                }
            }
        } label: {
            HStack {
                Text("#\(number)")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(AppTheme.standardPadding)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }
}

struct PositionPicker: View {
    @Binding var position: PlayerPosition
    
    var body: some View {
        Menu {
            ForEach(PlayerPosition.allCases, id: \.self) { pos in
                Button(pos.displayName) {
                    position = pos
                }
            }
        } label: {
            HStack {
                Text(position.displayName)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(AppTheme.standardPadding)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }
}

enum PlayerPosition: String, CaseIterable {
    case goalkeeper = "GK"
    case defender = "DEF"
    case midfielder = "MID"
    case forward = "FWD"
    
    var displayName: String {
        switch self {
        case .goalkeeper: return "Goalkeeper"
        case .defender: return "Defender"
        case .midfielder: return "Midfielder"
        case .forward: return "Forward"
        }
    }
}

struct PlayerDetailView: View {
    let player: Player
    let team: Team
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditPlayer = false
    @State private var selectedTimeframe: StatisticsTimeframe = .allTime
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Player header
                        playerHeaderSection
                        
                        // Stats overview cards
                        statsOverviewSection
                        
                        // Recent matches
                        recentMatchesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Player Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditPlayer = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
            .sheet(isPresented: $showingEditPlayer) {
                AddEditPlayerView(team: player.team!, player: player)
            }
        }
    }
    
    private var playerHeaderSection: some View {
        VStack(spacing: 16) {
            // Player avatar and basic info
            HStack(spacing: 20) {
                PlayerAvatar(player: player, size: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.name ?? "Unknown Player")
                        .font(AppTheme.headerFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    HStack {
                        Text("#\(player.jerseyNumber)")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.accentColor)
                            .fontWeight(.semibold)
                        
                        Text("•")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text(player.position ?? "No Position")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                Spacer()
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
    
    private var statsOverviewSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Goals",
                value: "\(playerStats.totalGoals)",
                icon: "soccerball",
                color: AppTheme.accentColor
            )
            
            StatCard(
                title: "Assists",
                value: "\(playerStats.totalAssists)",
                icon: "hand.thumbsup",
                color: .blue
            )
            
            StatCard(
                title: "Matches",
                value: "\(playerStats.matchesPlayed)",
                icon: "calendar",
                color: .orange
            )
            
            StatCard(
                title: "Minutes",
                value: "\(playerStats.totalMinutes)",
                icon: "clock",
                color: .purple
            )
        }
    }
    
    private var recentMatchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Matches")
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
            
            if filteredPlayerStats.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("No matches played yet")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(AppTheme.secondaryBackground)
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(filteredPlayerStats.prefix(5)), id: \.objectID) { stats in
                        PlayerMatchCard(stats: stats)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredPlayerStats: [PlayerStats] {
        let allStats = player.statisticsArray
        
        switch selectedTimeframe {
        case .allTime:
            return allStats
        case .lastMonth:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return allStats.filter { ($0.match?.date ?? Date()) >= oneMonthAgo }
        case .lastWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            return allStats.filter { ($0.match?.date ?? Date()) >= oneWeekAgo }
        }
    }
    
    private var playerStats: PlayerStatsSummary {
        PlayerStatsSummary(
            totalMinutes: filteredPlayerStats.reduce(0) { $0 + Int($1.minutesPlayed) },
            totalGoals: filteredPlayerStats.reduce(0) { $0 + Int($1.goals) },
            totalAssists: filteredPlayerStats.reduce(0) { $0 + Int($1.assists) },
            matchesPlayed: filteredPlayerStats.count
        )
    }
}

// MARK: - Supporting Views

struct PlayerMatchCard: View {
    let stats: PlayerStats
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: stats.match?.date ?? Date()))
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
                
                Text("vs \(stats.match?.team?.name ?? "Unknown")")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(stats.minutesPlayed)")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    Text("min")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                VStack(spacing: 2) {
                    Text("\(stats.goals)")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.accentColor)
                    Text("G")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                VStack(spacing: 2) {
                    Text("\(stats.assists)")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                    Text("A")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(8)
    }
}

