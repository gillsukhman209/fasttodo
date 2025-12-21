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
        VStack(spacing: 0) {
            // Top tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Theme.Colors.accent : Theme.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.Colors.accent.opacity(0.15))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.Colors.bg)

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .today:
                    TodayView()
                case .upcoming:
                    UpcomingView()
                }
            }
        }
        .background(Theme.Colors.bg)
        #endif
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
