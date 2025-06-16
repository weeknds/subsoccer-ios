import SwiftUI
import CoreData

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: true)],
        animation: .default)
    private var trainingSessions: FetchedResults<TrainingSession>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Match.date, ascending: true)],
        animation: .default)
    private var matches: FetchedResults<Match>
    
    @State private var selectedDate = Date()
    @State private var showingEventCreation = false
    @State private var viewMode: ViewMode = .month
    
    enum ViewMode {
        case month, day
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // View Mode Selector
                    Picker("View Mode", selection: $viewMode) {
                        Text("Month").tag(ViewMode.month)
                        Text("Day").tag(ViewMode.day)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, AppTheme.largePadding)
                    .padding(.top, AppTheme.standardPadding)
                    
                    if viewMode == .month {
                        monthView
                    } else {
                        dayView
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingEventCreation = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingEventCreation) {
                EventCreationView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private var monthView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                // Week day headers
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                        .frame(height: 30)
                }
                
                // Calendar days
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        events: eventsForDate(date),
                        onTap: {
                            selectedDate = date
                            viewMode = .day
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.largePadding)
        }
    }
    
    private var dayView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.largePadding) {
                // Selected date header
                HStack {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppTheme.accentColor)
                    }
                    
                    Spacer()
                    
                    Text(selectedDate, style: .date)
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
                .padding(.horizontal, AppTheme.largePadding)
                
                // Events for selected date
                let dayEvents = eventsForDate(selectedDate)
                if dayEvents.isEmpty {
                    VStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.secondaryText)
                            .padding(.bottom, 8)
                        
                        Text("No events scheduled")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Button("Add Event") {
                            showingEventCreation = true
                        }
                        .foregroundColor(AppTheme.accentColor)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: AppTheme.standardPadding) {
                        ForEach(dayEvents.sorted(by: { $0.date < $1.date }), id: \.id) { event in
                            if event.type == .training,
                               let trainingSession = findTrainingSession(for: event.id) {
                                NavigationLink(destination: TrainingSessionDetailView(session: trainingSession)) {
                                    EventCardView(event: event)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                EventCardView(event: event)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.largePadding)
                }
            }
        }
    }
    
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date] = []
        var currentDate = startOfWeek
        
        for _ in 0..<42 { // 6 weeks * 7 days
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        var events: [CalendarEvent] = []
        
        // Add training sessions
        for session in trainingSessions {
            if let sessionDate = session.date,
               calendar.isDate(sessionDate, inSameDayAs: date) {
                events.append(CalendarEvent(
                    id: session.id ?? UUID(),
                    title: session.title ?? "Training Session",
                    date: sessionDate,
                    type: .training,
                    location: session.location
                ))
            }
        }
        
        // Add matches
        for match in matches {
            if let matchDate = match.date,
               calendar.isDate(matchDate, inSameDayAs: date) {
                events.append(CalendarEvent(
                    id: match.id ?? UUID(),
                    title: "Match vs \(match.team?.name ?? "Unknown")",
                    date: matchDate,
                    type: .match,
                    location: nil
                ))
            }
        }
        
        return events
    }
    
    private func findTrainingSession(for eventId: UUID) -> TrainingSession? {
        return trainingSessions.first { $0.id == eventId }
    }
}

struct CalendarEvent: Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let type: EventType
    let location: String?
    
    enum EventType {
        case training, match
        
        var color: Color {
            switch self {
            case .training:
                return AppTheme.accentColor
            case .match:
                return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .training:
                return "figure.run"
            case .match:
                return "sportscourt"
            }
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let events: [CalendarEvent]
    let onTap: () -> Void
    
    private var isCurrentMonth: Bool {
        Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: Date())
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(textColor)
                
                // Event indicators
                HStack(spacing: 2) {
                    ForEach(events.prefix(3), id: \.id) { event in
                        Circle()
                            .fill(event.type.color)
                            .frame(width: 6, height: 6)
                    }
                    if events.count > 3 {
                        Text("+")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                .frame(height: 10)
            }
            .frame(width: 40, height: 50)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return AppTheme.secondaryText.opacity(0.5)
        } else if isToday {
            return AppTheme.primaryBackground
        } else if isSelected {
            return AppTheme.primaryBackground
        } else {
            return AppTheme.primaryText
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return AppTheme.accentColor
        } else if isSelected {
            return AppTheme.accentColor.opacity(0.8)
        } else {
            return Color.clear
        }
    }
}

struct EventCardView: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack {
            // Event type indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(event.type.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: event.type.icon)
                        .foregroundColor(event.type.color)
                    
                    Text(event.title)
                        .font(AppTheme.subheadFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Spacer()
                    
                    Text(event.date, style: .time)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(AppTheme.secondaryText)
                            .font(.caption)
                        
                        Text(location)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
            .padding(.leading, 8)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(AppTheme.cornerRadius)
    }
}