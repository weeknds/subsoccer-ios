import SwiftUI
import CoreData

struct TrainingSessionDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var session: TrainingSession
    @State private var showingAttendanceSheet = false
    @State private var showingDrillSheet = false
    @State private var showingEditSheet = false
    @State private var showingExportOptions = false
    @State private var showingPhotoGallery = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.largePadding) {
                        // Session Header
                        sessionHeaderView
                        
                        // Quick Actions
                        quickActionsView
                        
                        // Attendance Section
                        attendanceSection
                        
                        // Drills Section
                        drillsSection
                        
                        // Notes Section
                        notesSection
                    }
                    .padding(AppTheme.largePadding)
                }
            }
            .navigationTitle("Training Session")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Session") {
                            showingEditSheet = true
                        }
                        
                        Button("Delete Session", role: .destructive) {
                            deleteSession()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAttendanceSheet) {
            AttendanceTrackingView(session: session)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingDrillSheet) {
            DrillManagementView(session: session)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTrainingSessionView(session: session)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(match: nil, team: nil, trainingSession: session)
        }
        .sheet(isPresented: $showingPhotoGallery) {
            PhotoGalleryView(session: session)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private var sessionHeaderView: some View {
        VStack(spacing: AppTheme.standardPadding) {
            HStack {
                Image(systemName: "figure.run")
                    .font(.title)
                    .foregroundColor(AppTheme.accentColor)
                
                VStack(alignment: .leading) {
                    Text(session.title ?? "Training Session")
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    if let date = session.date {
                        Text(date, style: .date)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text(date, style: .time)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(session.duration) min")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.accentColor)
                    
                    if let location = session.location, !location.isEmpty {
                        Text(location)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }
    
    private var quickActionsView: some View {
        HStack(spacing: AppTheme.standardPadding) {
            Button(action: {
                showingAttendanceSheet = true
            }) {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentColor)
                    
                    Text("Attendance")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
            }
            
            Button(action: {
                showingDrillSheet = true
            }) {
                VStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentColor)
                    
                    Text("Drills")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
            }
            
            Button(action: {
                showingPhotoGallery = true
            }) {
                VStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentColor)
                    
                    Text("Photos")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.secondaryBackground)
                .cornerRadius(AppTheme.cornerRadius)
            }
        }
    }
    
    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            HStack {
                Text("Attendance")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                if let attendanceRecords = session.attendanceRecords?.allObjects as? [TrainingAttendance] {
                    let presentCount = attendanceRecords.filter { $0.isPresent }.count
                    let totalCount = attendanceRecords.count
                    
                    Text("\(presentCount)/\(totalCount)")
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.accentColor)
                }
            }
            
            if let attendanceRecords = session.attendanceRecords?.allObjects as? [TrainingAttendance],
               !attendanceRecords.isEmpty {
                LazyVStack(spacing: AppTheme.standardPadding / 2) {
                    ForEach(attendanceRecords.sorted(by: { 
                        ($0.player?.name ?? "") < ($1.player?.name ?? "")
                    }), id: \.self) { record in
                        AttendanceRowView(record: record)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("No attendance records yet")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Spacer()
                    
                    Button("Track Attendance") {
                        showingAttendanceSheet = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                .padding()
                .background(AppTheme.secondaryBackground.opacity(0.5))
                .cornerRadius(AppTheme.cornerRadius)
            }
        }
    }
    
    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            HStack {
                Text("Training Drills")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Button(action: {
                    showingDrillSheet = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(AppTheme.accentColor)
                }
            }
            
            if let drills = session.drills?.allObjects as? [TrainingDrill],
               !drills.isEmpty {
                LazyVStack(spacing: AppTheme.standardPadding) {
                    ForEach(drills.sorted(by: { $0.order < $1.order }), id: \.self) { drill in
                        DrillCardView(drill: drill)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "sportscourt")
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("No drills planned yet")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Spacer()
                    
                    Button("Add Drills") {
                        showingDrillSheet = true
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                .padding()
                .background(AppTheme.secondaryBackground.opacity(0.5))
                .cornerRadius(AppTheme.cornerRadius)
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
            Text("Session Notes")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(AppTheme.cornerRadius)
            } else {
                Text("No notes for this session")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.secondaryBackground.opacity(0.5))
                    .cornerRadius(AppTheme.cornerRadius)
            }
        }
    }
    
    private func deleteSession() {
        viewContext.delete(session)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error
        }
    }
}

struct AttendanceRowView: View {
    @ObservedObject var record: TrainingAttendance
    
    var body: some View {
        HStack {
            Image(systemName: record.isPresent ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(record.isPresent ? AppTheme.accentColor : .red)
            
            Text(record.player?.name ?? "Unknown Player")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
            
            Spacer()
            
            if let notes = record.notes, !notes.isEmpty {
                Image(systemName: "note.text")
                    .foregroundColor(AppTheme.secondaryText)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DrillCardView: View {
    @ObservedObject var drill: TrainingDrill
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardPadding / 2) {
            HStack {
                Text(drill.name ?? "Unnamed Drill")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Spacer()
                
                Text("\(drill.duration) min")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.accentColor)
            }
            
            if let description = drill.drillDescription, !description.isEmpty {
                Text(description)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
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
    
    return TrainingSessionDetailView(session: session)
        .environment(\.managedObjectContext, context)
}