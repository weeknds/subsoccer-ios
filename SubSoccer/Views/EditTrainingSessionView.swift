import SwiftUI
import CoreData

struct EditTrainingSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var session: TrainingSession
    
    @State private var title: String
    @State private var selectedDate: Date
    @State private var duration: Int
    @State private var location: String
    @State private var notes: String
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>
    
    @State private var selectedTeam: Team?
    
    init(session: TrainingSession) {
        self.session = session
        self._title = State(initialValue: session.title ?? "")
        self._selectedDate = State(initialValue: session.date ?? Date())
        self._duration = State(initialValue: Int(session.duration))
        self._location = State(initialValue: session.location ?? "")
        self._notes = State(initialValue: session.notes ?? "")
        self._selectedTeam = State(initialValue: session.team)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.largePadding) {
                        // Title Field
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Title")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            TextField("Enter session title", text: $title)
                                .textFieldStyle(AppTextFieldStyle())
                        }
                        
                        // Team Selection
                        if !teams.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                                Text("Team")
                                    .font(AppTheme.subheadFont)
                                    .foregroundColor(AppTheme.primaryText)
                                
                                Menu {
                                    Button("No Team") {
                                        selectedTeam = nil
                                    }
                                    
                                    ForEach(teams, id: \.self) { team in
                                        Button(team.name ?? "Unknown Team") {
                                            selectedTeam = team
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedTeam?.name ?? "Select Team")
                                            .foregroundColor(selectedTeam == nil ? AppTheme.secondaryText : AppTheme.primaryText)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(AppTheme.secondaryText)
                                    }
                                    .padding()
                                    .background(AppTheme.secondaryBackground)
                                    .cornerRadius(AppTheme.cornerRadius)
                                }
                            }
                        }
                        
                        // Date and Time
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Date & Time")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            DatePicker("Session Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(CompactDatePickerStyle())
                                .colorScheme(.dark)
                        }
                        
                        // Duration
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Duration")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            HStack {
                                Text("\(duration) minutes")
                                    .foregroundColor(AppTheme.primaryText)
                                
                                Spacer()
                                
                                Slider(value: Binding(
                                    get: { Double(duration) },
                                    set: { duration = Int($0) }
                                ), in: 30...180, step: 15)
                                .accentColor(AppTheme.accentColor)
                                .frame(width: 200)
                            }
                            .padding()
                            .background(AppTheme.secondaryBackground)
                            .cornerRadius(AppTheme.cornerRadius)
                        }
                        
                        // Location
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Location")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            TextField("Enter location", text: $location)
                                .textFieldStyle(AppTextFieldStyle())
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Notes")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding()
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(AppTheme.cornerRadius)
                                .colorScheme(.dark)
                        }
                    }
                    .padding(AppTheme.largePadding)
                }
            }
            .navigationTitle("Edit Session")
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
                        saveChanges()
                    }
                    .foregroundColor(canSave ? AppTheme.accentColor : AppTheme.secondaryText)
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveChanges() {
        session.title = title
        session.date = selectedDate
        session.duration = Int16(duration)
        session.location = location.isEmpty ? nil : location
        session.notes = notes.isEmpty ? nil : notes
        session.team = selectedTeam
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save changes: \(error)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let session = TrainingSession(context: context)
    session.title = "Morning Practice"
    session.date = Date()
    session.duration = 90
    session.location = "Main Field"
    session.notes = "Focus on passing and ball control"
    session.id = UUID()
    
    return EditTrainingSessionView(session: session)
        .environment(\.managedObjectContext, context)
}