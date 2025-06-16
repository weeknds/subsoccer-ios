import SwiftUI
import CoreData

struct TeamsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.createdAt, ascending: false)],
        animation: .default
    ) private var teams: FetchedResults<Team>
    
    @State private var showingAddTeam = false
    @State private var selectedTeam: Team?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                if teams.isEmpty {
                    EmptyTeamsView()
                } else {
                    TeamsListView(teams: teams, selectedTeam: $selectedTeam)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton {
                            showingAddTeam = true
                        }
                        .padding(.trailing, AppTheme.largePadding)
                        .padding(.bottom, AppTheme.largePadding)
                    }
                }
            }
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAddTeam) {
                AddEditTeamView()
            }
            .sheet(item: $selectedTeam) { team in
                TeamDetailView(team: team)
            }
        }
    }
}

struct EmptyTeamsView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.accentColor)
                .padding(.bottom, 20)
            
            Text("No Teams Yet")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 8)
            
            Text("Create your first team to get started with managing players and matches")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

struct TeamsListView: View {
    let teams: FetchedResults<Team>
    @Binding var selectedTeam: Team?
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.standardPadding) {
                ForEach(teams, id: \.self) { team in
                    TeamCard(team: team) {
                        selectedTeam = team
                    }
                    .contextMenu {
                        Button("Edit Team") {
                            selectedTeam = team
                        }
                        Button("Delete Team", role: .destructive) {
                            deleteTeam(team)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            deleteTeam(team)
                        }
                        Button("Edit") {
                            selectedTeam = team
                        }
                        .tint(AppTheme.accentColor)
                    }
                }
            }
            .padding(.horizontal, AppTheme.largePadding)
            .padding(.bottom, 80) // Space for FAB
        }
    }
    
    private func deleteTeam(_ team: Team) {
        withAnimation {
            viewContext.delete(team)
            
            do {
                try viewContext.save()
            } catch {
                // Handle error
                print("Error deleting team: \(error)")
            }
        }
    }
}

struct TeamCard: View {
    let team: Team
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name ?? "Unnamed Team")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.primaryText)
                            .lineLimit(1)
                        
                        Text("\(team.players?.count ?? 0) players")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                if let createdAt = team.createdAt {
                    Text("Created \(createdAt, style: .date)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .padding(AppTheme.largePadding)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(AppTheme.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

struct AddEditTeamView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let team: Team?
    @State private var teamName = ""
    
    init(team: Team? = nil) {
        self.team = team
        self._teamName = State(initialValue: team?.name ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: AppTheme.largePadding) {
                    VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                        Text("Team Name")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        TextField("Enter team name", text: $teamName)
                            .textFieldStyle(AppTextFieldStyle())
                    }
                    
                    Spacer()
                }
                .padding(AppTheme.largePadding)
            }
            .navigationTitle(team == nil ? "New Team" : "Edit Team")
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
                        saveTeam()
                    }
                    .foregroundColor(AppTheme.accentColor)
                    .disabled(teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveTeam() {
        let teamToSave = team ?? Team(context: viewContext)
        teamToSave.name = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if team == nil {
            teamToSave.id = UUID()
            teamToSave.createdAt = Date()
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving team: \(error)")
        }
    }
}


struct TeamDetailView: View {
    let team: Team
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditTeam = false
    @State private var showingPlayerManagement = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: AppTheme.largePadding) {
                    VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                        Text(team.name ?? "Unnamed Team")
                            .font(AppTheme.headerFont)
                            .foregroundColor(AppTheme.primaryText)
                        
                        Text("\(team.players?.count ?? 0) players")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        if let createdAt = team.createdAt {
                            Text("Created \(createdAt, style: .date)")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                    
                    Button(action: {
                        showingPlayerManagement = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage Players")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.primaryText)
                                
                                Text("Add, edit, and organize team players")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.secondaryText)
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
                    
                    Spacer()
                }
                .padding(AppTheme.largePadding)
            }
            .navigationTitle("Team Details")
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
                        showingEditTeam = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
            .sheet(isPresented: $showingEditTeam) {
                AddEditTeamView(team: team)
            }
            .sheet(isPresented: $showingPlayerManagement) {
                PlayerManagementView(team: team)
            }
        }
    }
}