import SwiftUI

struct TodayView: View {
    @State private var inputText: String = ""
    @State private var isDarkMode: Bool = true

    // Placeholder tasks
    private var tasks: [TaskModel] {
        [
            TaskModel(title: "Morning workout", time: "6:30 AM", isRecurring: true),
            TaskModel(title: "Review design mockups", time: "10:00 AM", isRecurring: false),
            TaskModel(title: "Team standup", time: "11:00 AM", isRecurring: true),
            TaskModel(title: "Lunch with Sarah", time: "1:00 PM", isRecurring: false),
            TaskModel(title: "Call mom", time: "7:00 PM", isRecurring: false),
            TaskModel(title: "Buy groceries", time: nil, isRecurring: false),
            TaskModel(title: "Read 20 pages", time: nil, isRecurring: false),
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Theme.Colors.bg
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: isDarkMode)

            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HeaderView(completed: 3, total: tasks.count, isDarkMode: $isDarkMode)

                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(height: 1)
                        .padding(.horizontal, Theme.Space.lg)

                    // Tasks section
                    VStack(spacing: 0) {
                        // Section header
                        HStack {
                            SectionLabel("Tasks", count: tasks.count)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.lg)
                        .padding(.bottom, Theme.Space.md)

                        // Task list
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                                TaskItem(task: task)

                                if index < tasks.count - 1 {
                                    Divider()
                                        .background(Theme.Colors.border)
                                        .padding(.leading, 56)
                                }
                            }
                        }
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: 120)
                }
            }
            .scrollIndicators(.hidden)

            // Input bar
            VStack(spacing: 0) {
                // Gradient fade
                LinearGradient(
                    colors: [
                        Theme.Colors.bg.opacity(0),
                        Theme.Colors.bg
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)

                InputBar(text: $inputText)
                    .padding(.bottom, Theme.Space.md)
                    .background(Theme.Colors.bg)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview {
    TodayView()
}
