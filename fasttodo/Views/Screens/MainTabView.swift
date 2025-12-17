import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .today

    enum Tab {
        case today
        case upcoming
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            UpcomingView()
                .tabItem {
                    Label("Upcoming", systemImage: "calendar")
                }
                .tag(Tab.upcoming)
        }
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
