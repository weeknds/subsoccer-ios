import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TeamsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Teams")
                        .font(AppTheme.scaledFont(.caption))
                }
                .accessibilityLabel("Teams tab")
                .accessibilityHint("Navigate to team management")
            
            MatchesView()
                .tabItem {
                    Image(systemName: "sportscourt.fill")
                    Text("Matches")
                        .font(AppTheme.scaledFont(.caption))
                }
                .accessibilityLabel("Matches tab")
                .accessibilityHint("Navigate to match management")
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                        .font(AppTheme.scaledFont(.caption))
                }
                .accessibilityLabel("Calendar tab")
                .accessibilityHint("Navigate to training calendar")
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                        .font(AppTheme.scaledFont(.caption))
                }
                .accessibilityLabel("Settings tab")
                .accessibilityHint("Navigate to app settings")
        }
        .preferredColorScheme(.dark)
        .accentColor(AppTheme.accentColor)
    }
}