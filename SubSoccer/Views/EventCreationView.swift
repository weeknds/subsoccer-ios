import SwiftUI
import CoreData

struct EventCreationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>
    
    @State private var selectedEventType: EventType = .training
    @State private var title = ""
    @State private var selectedDate = Date()
    @State private var duration = 90
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedTeam: Team?
    
    enum EventType: String, CaseIterable {
        case training = "Training"
        case match = "Match"
        
        var icon: String {
            switch self {
            case .training:
                return "figure.run"
            case .match:
                return "sportscourt"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.largePadding) {
                        // Event Type Selector
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Event Type")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            Picker("Event Type", selection: $selectedEventType) {
                                ForEach(EventType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Title Field
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Title")
                                .font(AppTheme.subheadFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            TextField("Enter event title", text: $title)
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
                            
                            DatePicker("Event Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
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
            .navigationTitle("New Event")
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
                        saveEvent()
                    }
                    .foregroundColor(canSave ? AppTheme.accentColor : AppTheme.secondaryText)
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedTeam != nil
    }
    
    private func saveEvent() {
        withAnimation {
            if selectedEventType == .training {
                let trainingSession = TrainingSession(context: viewContext)
                trainingSession.id = UUID()
                trainingSession.title = title
                trainingSession.date = selectedDate
                trainingSession.duration = Int16(duration)
                trainingSession.location = location
                trainingSession.notes = notes
                trainingSession.type = selectedEventType.rawValue
                trainingSession.team = selectedTeam
            } else {
                let match = Match(context: viewContext)
                match.id = UUID()
                match.date = selectedDate
                match.duration = Int16(duration)
                match.team = selectedTeam
                match.numberOfHalves = 2
                match.hasOvertime = false
            }
            
            try? viewContext.save()
            dismiss()
        }
    }
}


#Preview {
    EventCreationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}