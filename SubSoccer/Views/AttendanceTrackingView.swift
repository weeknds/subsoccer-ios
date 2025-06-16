import SwiftUI
import CoreData

struct AttendanceTrackingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var session: TrainingSession
    @State private var attendanceRecords: [String: AttendanceRecord] = [:]
    @State private var searchText = ""
    
    struct AttendanceRecord {
        var isPresent: Bool = false
        var notes: String = ""
    }
    
    private var team: Team? {
        session.team
    }
    
    private var players: [Player] {
        guard let team = team,
              let teamPlayers = team.players?.allObjects as? [Player] else {
            return []
        }
        
        return teamPlayers.filter { player in
            if searchText.isEmpty {
                return true
            } else {
                return (player.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBarView
                    
                    // Player List
                    ScrollView {
                        LazyVStack(spacing: AppTheme.standardPadding) {
                            ForEach(players, id: \.self) { player in
                                PlayerAttendanceCard(
                                    player: player,
                                    record: Binding(
                                        get: {
                                            attendanceRecords[player.id?.uuidString ?? ""] ?? AttendanceRecord()
                                        },
                                        set: { newValue in
                                            attendanceRecords[player.id?.uuidString ?? ""] = newValue
                                        }
                                    )
                                )
                            }
                        }
                        .padding(AppTheme.largePadding)
                    }
                }
            }
            .navigationTitle("Take Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAttendance()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
        .onAppear {
            loadExistingAttendance()
        }
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.secondaryText)
            
            TextField("Search players...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(AppTheme.primaryText)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .padding(.horizontal, AppTheme.largePadding)
        .padding(.top, AppTheme.standardPadding)
    }
    
    private func loadExistingAttendance() {
        if let existingRecords = session.attendanceRecords?.allObjects as? [TrainingAttendance] {
            for record in existingRecords {
                if let playerId = record.player?.id?.uuidString {
                    attendanceRecords[playerId] = AttendanceRecord(
                        isPresent: record.isPresent,
                        notes: record.notes ?? ""
                    )
                }
            }
        }
    }
    
    private func saveAttendance() {
        // Clear existing attendance records
        if let existingRecords = session.attendanceRecords?.allObjects as? [TrainingAttendance] {
            for record in existingRecords {
                viewContext.delete(record)
            }
        }
        
        // Create new attendance records
        for player in players {
            guard let playerId = player.id?.uuidString,
                  let record = attendanceRecords[playerId] else { continue }
            
            let attendanceRecord = TrainingAttendance(context: viewContext)
            attendanceRecord.id = UUID()
            attendanceRecord.player = player
            attendanceRecord.session = session
            attendanceRecord.isPresent = record.isPresent
            attendanceRecord.notes = record.notes.isEmpty ? nil : record.notes
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error
            print("Failed to save attendance: \(error)")
        }
    }
}

struct PlayerAttendanceCard: View {
    let player: Player
    @Binding var record: AttendanceTrackingView.AttendanceRecord
    @State private var showingNotesSheet = false
    
    var body: some View {
        HStack {
            // Player Info
            HStack {
                // Profile Image
                if let imageData = player.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.secondaryBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(player.name?.prefix(1) ?? "?"))
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name ?? "Unknown Player")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    HStack {
                        Text("#\(player.jerseyNumber)")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text("•")
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text(player.position ?? "")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                Spacer()
            }
            
            // Attendance Controls
            HStack(spacing: AppTheme.largePadding) {
                // Notes Button
                Button(action: {
                    showingNotesSheet = true
                }) {
                    Image(systemName: record.notes.isEmpty ? "note.text" : "note.text.badge.plus")
                        .foregroundColor(record.notes.isEmpty ? AppTheme.secondaryText : AppTheme.accentColor)
                        .font(.title3)
                }
                
                // Attendance Toggle
                Button(action: {
                    record.isPresent.toggle()
                }) {
                    Image(systemName: record.isPresent ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(record.isPresent ? AppTheme.accentColor : AppTheme.secondaryText)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .sheet(isPresented: $showingNotesSheet) {
            PlayerNotesSheet(playerName: player.name ?? "Player", notes: $record.notes)
        }
    }
}

struct PlayerNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let playerName: String
    @Binding var notes: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: AppTheme.largePadding) {
                    Text("Notes for \(playerName)")
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    TextEditor(text: $notes)
                        .padding()
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(AppTheme.cornerRadius)
                        .colorScheme(.dark)
                    
                    Spacer()
                }
                .padding(AppTheme.largePadding)
            }
            .navigationTitle("Player Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create a team with players
    let team = Team(context: context)
    team.name = "Test Team"
    team.id = UUID()
    
    let player1 = Player(context: context)
    player1.name = "John Doe"
    player1.jerseyNumber = 10
    player1.position = "FWD"
    player1.id = UUID()
    player1.team = team
    
    let player2 = Player(context: context)
    player2.name = "Jane Smith"
    player2.jerseyNumber = 7
    player2.position = "MID"
    player2.id = UUID()
    player2.team = team
    
    let session = TrainingSession(context: context)
    session.title = "Morning Practice"
    session.team = team
    session.id = UUID()
    
    return AttendanceTrackingView(session: session)
        .environment(\.managedObjectContext, context)
}