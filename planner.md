# SubSoccer - iOS App Development Specification

## Design System & UI Guidelines
- **Primary Background**: Pure black (#000000)
- **Secondary Background**: Dark gray (#1C1C1E)
- **Accent Color**: Neon lime green (#00FF00)
- **Primary Text**: White (#FFFFFF)
- **Secondary Text**: Gray (#8E8E93)
- **Component Style**: Rounded corners (12-16px radius), subtle shadows
- **Typography**: SF Pro Display for headers, SF Pro Text for body
- **Spacing**: Use consistent 8pt grid system
- **Platform**: iOS 18+ (iPhone and iPad Universal)

## Phase 1: Foundation & Core Data

### 1.1 Project Setup
- Create new SwiftUI iOS app targeting iOS 18+
- Configure for iPhone and iPad (universal app)
- Set up Core Data models for offline storage
- Implement dark theme color scheme from day one

### 1.2 Data Models
Create Core Data entities:
```
Team:
- id: UUID
- name: String
- createdAt: Date
- players: [Player] relationship

Player:
- id: UUID
- name: String
- jerseyNumber: Int16
- position: String
- profileImageData: Data?
- team: Team relationship
- statistics: [PlayerStats] relationship

Match:
- id: UUID
- date: Date
- duration: Int16
- numberOfHalves: Int16
- hasOvertime: Bool
- team: Team relationship
- events: [MatchEvent] relationship

PlayerStats:
- id: UUID
- minutesPlayed: Int16
- goals: Int16
- assists: Int16
- player: Player relationship
- match: Match relationship
```

### 1.3 Basic Navigation
- Implement tab bar with icons matching the lime green accent
- Create main views: Teams, Matches, Calendar, Settings
- Use NavigationStack for drill-down navigation

## Phase 2: Team Management

### 2.1 Team List View
- Display teams in cards with black background
- Add floating action button (FAB) with lime green accent
- Implement swipe actions for edit/delete

### 2.2 Player Management
- Create/edit player form with:
  - Text fields with dark styling
  - Photo picker for profile images
  - Position selector (GK, DEF, MID, FWD)
  - Number picker (1-99)
- Player list with search functionality
- Player cards showing photo, name, number, position

## Phase 3: Match Configuration & Live Mode

### 3.1 Match Setup
- Match configuration screen with:
  - Duration slider (styled with lime accent)
  - Halves selector (1-4)
  - Overtime toggle switch
  - Team selection
- Save configuration to Core Data

### 3.2 Live Match Interface
- Soccer field visualization:
  - Dark green gradient background
  - White lines for field markings
  - Player tokens (circular with jersey numbers)
- Drag-and-drop functionality:
  - Smooth animations
  - Haptic feedback
  - Visual feedback (lime green glow on drag)
- Match timer with start/pause/stop controls
- Substitution panel (slide-up drawer)

## Phase 4: Substitution Systems

### 4.1 Substitution Modes
Implement three modes with visual mode selector:
1. **Turn-based**: Queue visualization with next-up indicator
2. **Pre-marked**: Toggle UI for selecting active players
3. **Color groups**: Assign players to color-coded groups

### 4.2 Substitution UI
- Quick-sub buttons with lime green active state
- Substitution history in collapsible panel
- Manual override with confirmation dialog
- Time-based alerts (customizable intervals)

## Phase 5: Statistics & History

### 5.1 Player Statistics
- Stats dashboard with:
  - Circular progress charts (playtime distribution)
  - Bar charts for goals/assists
  - Season overview cards
- Individual player detail view
- Comparison view between players

### 5.2 Match History
- Match list with results
- Match detail view showing:
  - Timeline of events
  - Player participation grid
  - Final statistics
- Filter and sort capabilities

## Phase 6: Training Calendar

### 6.1 Calendar View
- Monthly calendar with training/match indicators
- Day view for detailed scheduling
- Event creation with:
  - Type selector (Training/Match)
  - Time picker
  - Location field
  - Notes section

### 6.2 Training Management
- Attendance tracking with checkboxes
- Exercise/drill library
- Session notes with rich text
- Quick actions for common tasks

## Phase 7: Supabase Integration

### 7.1 Backend Setup
- Configure Supabase project
- Create database schema matching Core Data
- Set up authentication (email/magic link)
- Implement Row Level Security policies

### 7.2 Sync Engine
- Build sync service with:
  - Conflict resolution
  - Offline queue management
  - Progress indicators
  - Manual sync trigger
- Settings for sync preferences
- Account management UI

## Phase 8: Advanced Features

### 8.1 Export & Sharing
- PDF generation for match reports
- CSV export for statistics
- Share sheet integration

### 8.2 AI Lineup Suggestions
- Algorithm for balanced playtime
- Formation recommendations
- Availability consideration
- Manual override options

### 8.3 Media & Notes
- Photo attachment to sessions
- Player tagging in photos
- Note organization system

### 8.4 Injury Management
- Mark players as injured/unavailable
- Injury history tracking
- Automatic exclusion from lineups
- Return-to-play tracking

### 8.5 Notifications
- Local notifications for upcoming matches/training
- In-match substitution reminders
- Custom alert configurations

## Phase 9: Polish & Optimization

### 9.1 Performance
- Optimize Core Data queries
- Implement lazy loading
- Image caching and compression
- Animation performance tuning

### 9.2 Accessibility & Localization
- VoiceOver support
- Dynamic Type support
- English and Swedish localization
- RTL language preparation

### 9.3 iPad Optimization
- Split view layouts
- Keyboard shortcuts
- Drag and drop between views
- Optimized landscape layouts

## Technical Requirements

### Core Technologies
- **Minimum iOS Version**: 18.0
- **Architecture**: MVVM with SwiftUI
- **Storage**: Core Data for local, Supabase for cloud
- **Dependencies**: 
  - Supabase Swift SDK
  - Charts framework (native)
  - PDFKit for exports

### Key Implementation Guidelines

1. **Offline-First Architecture**
   - All core features work without internet
   - Supabase sync is optional and user-initiated
   - Local data is source of truth

2. **UI/UX Principles**
   - Force dark mode throughout the app
   - Lime green (#00FF00) for all interactive elements
   - Haptic feedback on all touch interactions
   - Smooth 60fps animations

3. **Data Management**
   - Use `@Observable` macro (iOS 17+) for view models
   - Implement proper Core Data background contexts
   - Cache all images locally
   - Implement data validation

4. **Performance Considerations**
   - Lazy load lists and grids
   - Optimize image sizes before storage
   - Use `task` modifier for async operations
   - Implement proper cancellation

5. **Error Handling**
   - User-friendly error messages
   - Retry mechanisms for network operations
   - Graceful fallbacks
   - Error logging for debugging

6. **Testing Strategy**
   - Unit tests for business logic
   - UI tests for critical user flows
   - Performance tests for large datasets
   - Accessibility audits

## App Store Requirements

### Screenshots & Marketing
- Prepare screenshots highlighting:
  - Live match mode with substitutions
  - Team management interface
  - Statistics dashboard
  - Training calendar

### App Description Keywords
- Youth soccer coach
- Team management
- Substitution tracker
- Player statistics
- Offline-first
- Training planner

### Privacy & Permissions
- Camera (for player photos)
- Notifications (for reminders)
- No location tracking
- GDPR compliant data handling

## Future Considerations

### Potential Features (Post-Launch)
- Apple Watch companion app for match day
- Team communication features
- Video analysis integration
- Tournament mode
- Parent/player app for availability
- Coach collaboration features
- Advanced analytics with ML
- Integration with league systems

### Monetization Options
- Free with premium features
- Team size limits for free tier
- Advanced statistics in premium
- Multi-team support in premium
- No ads in core functionality