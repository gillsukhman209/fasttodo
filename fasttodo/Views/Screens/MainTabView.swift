import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .today

    enum Tab: String, CaseIterable {
        case today
        case upcoming

        var title: String {
            switch self {
            case .today: return "Today"
            case .upcoming: return "Upcoming"
            }
        }

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .upcoming: return "calendar"
            }
        }
    }

    var body: some View {
        #if os(iOS)
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
        #else
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("FastTodo")
        } detail: {
            switch selectedTab {
            case .today:
                TodayView()
            case .upcoming:
                UpcomingView()
            }
        }
        .tint(Theme.Colors.accent)
        #endif
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
