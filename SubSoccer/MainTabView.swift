import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TeamsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Teams")
                }
            
            MatchesView()
                .tabItem {
                    Image(systemName: "sportscourt.fill")
                    Text("Matches")
                }
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .preferredColorScheme(.dark)
        .accentColor(AppTheme.accentColor)
    }
}