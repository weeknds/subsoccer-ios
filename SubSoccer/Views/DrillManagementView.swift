import SwiftUI
import CoreData

struct DrillManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var session: TrainingSession
    @State private var showingAddDrill = false
    @State private var drillsFromLibrary: [DrillTemplate] = []
    
    private var drills: [TrainingDrill] {
        (session.drills?.allObjects as? [TrainingDrill] ?? [])
            .sorted { $0.order < $1.order }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if drills.isEmpty {
                        emptyStateView
                    } else {
                        drillListView
                    }
                }
            }
            .navigationTitle("Training Drills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddDrill = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddDrill) {
            AddDrillView(session: session)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            loadDrillLibrary()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.largePadding) {
            Spacer()
            
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.secondaryText)
            
            Text("No Drills Added")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
            
            Text("Add drills to structure your training session")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Add First Drill") {
                showingAddDrill = true
            }
            .padding()
            .background(AppTheme.accentColor)
            .foregroundColor(AppTheme.primaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
            
            // Quick Add from Library
            if !drillsFromLibrary.isEmpty {
                VStack(spacing: AppTheme.standardPadding) {
                    Text("Or choose from library:")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    LazyVStack(spacing: AppTheme.standardPadding / 2) {
                        ForEach(drillsFromLibrary.prefix(3), id: \.id) { template in
                            Button(action: {
                                addDrillFromTemplate(template)
                            }) {
                                HStack {
                                    Text(template.name)
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.primaryText)
                                    
                                    Spacer()
                                    
                                    Text("\(template.duration) min")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.accentColor)
                                }
                                .padding()
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(AppTheme.cornerRadius)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
            
            Spacer()
        }
        .padding(AppTheme.largePadding)
    }
    
    private var drillListView: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.standardPadding) {
                ForEach(drills, id: \.self) { drill in
                    DrillRowView(drill: drill, onDelete: {
                        deleteDrill(drill)
                    }, onMoveUp: {
                        moveDrill(drill, direction: -1)
                    }, onMoveDown: {
                        moveDrill(drill, direction: 1)
                    })
                }
            }
            .padding(AppTheme.largePadding)
        }
    }
    
    private func loadDrillLibrary() {
        drillsFromLibrary = [
            DrillTemplate(id: UUID(), name: "Passing Circle", description: "Players form a circle and practice passing accuracy", duration: 15, category: "Passing"),
            DrillTemplate(id: UUID(), name: "1v1 Finishing", description: "Players practice finishing in 1v1 situations", duration: 20, category: "Shooting"),
            DrillTemplate(id: UUID(), name: "Cone Dribbling", description: "Dribble through cones to improve ball control", duration: 10, category: "Dribbling"),
            DrillTemplate(id: UUID(), name: "Keep Ball Up", description: "Teams try to maintain possession", duration: 15, category: "Possession"),
            DrillTemplate(id: UUID(), name: "Sprint Intervals", description: "High-intensity running intervals", duration: 12, category: "Fitness"),
            DrillTemplate(id: UUID(), name: "Defensive Shape", description: "Practice maintaining defensive formation", duration: 20, category: "Defense")
        ]
    }
    
    private func addDrillFromTemplate(_ template: DrillTemplate) {
        let drill = TrainingDrill(context: viewContext)
        drill.id = UUID()
        drill.name = template.name
        drill.drillDescription = template.description
        drill.duration = Int16(template.duration)
        drill.order = Int16(drills.count)
        drill.session = session
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to add drill: \(error)")
        }
    }
    
    private func deleteDrill(_ drill: TrainingDrill) {
        viewContext.delete(drill)
        
        // Reorder remaining drills
        let remainingDrills = drills.filter { $0 != drill }
        for (index, remainingDrill) in remainingDrills.enumerated() {
            remainingDrill.order = Int16(index)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete drill: \(error)")
        }
    }
    
    private func moveDrill(_ drill: TrainingDrill, direction: Int) {
        let currentIndex = Int(drill.order)
        let newIndex = currentIndex + direction
        
        guard newIndex >= 0 && newIndex < drills.count else { return }
        
        // Swap orders
        let otherDrill = drills[newIndex]
        drill.order = Int16(newIndex)
        otherDrill.order = Int16(currentIndex)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to move drill: \(error)")
        }
    }
}

struct DrillTemplate {
    let id: UUID
    let name: String
    let description: String
    let duration: Int
    let category: String
}

struct DrillRowView: View {
    @ObservedObject var drill: TrainingDrill
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.standardPadding / 2) {
                HStack {
                    Text(drill.name ?? "Unnamed Drill")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Spacer()
                    
                    Text("\(drill.duration) min")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if let description = drill.drillDescription, !description.isEmpty {
                    Text(description)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            
            VStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(AppTheme.secondaryText)
                        .font(.caption)
                }
                
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppTheme.secondaryText)
                        .font(.caption)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
    }
}

struct AddDrillView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var session: TrainingSession
    @State private var drillName = ""
    @State private var drillDescription = ""
    @State private var duration = 15
    @State private var selectedTemplate: DrillTemplate?
    
    private let drillTemplates = [
        DrillTemplate(id: UUID(), name: "Passing Circle", description: "Players form a circle and practice passing accuracy", duration: 15, category: "Passing"),
        DrillTemplate(id: UUID(), name: "1v1 Finishing", description: "Players practice finishing in 1v1 situations", duration: 20, category: "Shooting"),
        DrillTemplate(id: UUID(), name: "Cone Dribbling", description: "Dribble through cones to improve ball control", duration: 10, category: "Dribbling"),
        DrillTemplate(id: UUID(), name: "Keep Ball Up", description: "Teams try to maintain possession", duration: 15, category: "Possession"),
        DrillTemplate(id: UUID(), name: "Sprint Intervals", description: "High-intensity running intervals", duration: 12, category: "Fitness"),
        DrillTemplate(id: UUID(), name: "Defensive Shape", description: "Practice maintaining defensive formation", duration: 20, category: "Defense")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.largePadding) {
                        // Template Selection
                        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                            Text("Choose from Library")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            LazyVStack(spacing: AppTheme.standardPadding / 2) {
                                ForEach(drillTemplates, id: \.id) { template in
                                    Button(action: {
                                        selectTemplate(template)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(template.name)
                                                    .font(AppTheme.subheadFont)
                                                    .foregroundColor(AppTheme.primaryText)
                                                
                                                Text(template.description)
                                                    .font(AppTheme.captionFont)
                                                    .foregroundColor(AppTheme.secondaryText)
                                                    .lineLimit(2)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack {
                                                Text("\(template.duration) min")
                                                    .font(AppTheme.captionFont)
                                                    .foregroundColor(AppTheme.accentColor)
                                                
                                                Text(template.category)
                                                    .font(.caption2)
                                                    .foregroundColor(AppTheme.secondaryText)
                                            }
                                        }
                                        .padding()
                                        .background(selectedTemplate?.id == template.id ? AppTheme.accentColor.opacity(0.2) : AppTheme.secondaryBackground)
                                        .cornerRadius(AppTheme.cornerRadius)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .background(AppTheme.secondaryText)
                        
                        // Custom Drill
                        VStack(alignment: .leading, spacing: AppTheme.largePadding) {
                            Text("Or Create Custom")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.primaryText)
                            
                            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                                Text("Drill Name")
                                    .font(AppTheme.subheadFont)
                                    .foregroundColor(AppTheme.primaryText)
                                
                                TextField("Enter drill name", text: $drillName)
                                    .textFieldStyle(AppTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                                Text("Description")
                                    .font(AppTheme.subheadFont)
                                    .foregroundColor(AppTheme.primaryText)
                                
                                TextEditor(text: $drillDescription)
                                    .frame(minHeight: 80)
                                    .padding()
                                    .background(AppTheme.secondaryBackground)
                                    .cornerRadius(AppTheme.cornerRadius)
                                    .colorScheme(.dark)
                            }
                            
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
                                    ), in: 5...60, step: 5)
                                    .accentColor(AppTheme.accentColor)
                                    .frame(width: 200)
                                }
                                .padding()
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(AppTheme.cornerRadius)
                            }
                        }
                    }
                    .padding(AppTheme.largePadding)
                }
            }
            .navigationTitle("Add Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addDrill()
                    }
                    .foregroundColor(canAdd ? AppTheme.accentColor : AppTheme.secondaryText)
                    .disabled(!canAdd)
                }
            }
        }
    }
    
    private var canAdd: Bool {
        if selectedTemplate != nil {
            return true
        }
        return !drillName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func selectTemplate(_ template: DrillTemplate) {
        if selectedTemplate?.id == template.id {
            selectedTemplate = nil
        } else {
            selectedTemplate = template
            drillName = template.name
            drillDescription = template.description
            duration = template.duration
        }
    }
    
    private func addDrill() {
        let drill = TrainingDrill(context: viewContext)
        drill.id = UUID()
        drill.name = drillName
        drill.drillDescription = drillDescription.isEmpty ? nil : drillDescription
        drill.duration = Int16(duration)
        drill.session = session
        
        // Set order to be last
        let existingDrills = session.drills?.allObjects as? [TrainingDrill] ?? []
        drill.order = Int16(existingDrills.count)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to add drill: \(error)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let session = TrainingSession(context: context)
    session.title = "Morning Practice"
    session.id = UUID()
    
    return DrillManagementView(session: session)
        .environment(\.managedObjectContext, context)
}