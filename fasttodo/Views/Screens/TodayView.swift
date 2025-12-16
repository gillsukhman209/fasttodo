import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var tasks: [TodoItem]

    @State private var inputText: String = ""
    @State private var isDarkMode: Bool = true
    @State private var taskToEdit: TodoItem?

    private let parser = NaturalLanguageParser()

    // Computed properties for stats
    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var incompleteTasks: [TodoItem] {
        tasks.filter { !$0.isCompleted }
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
                    HeaderView(completed: completedCount, total: tasks.count, isDarkMode: $isDarkMode)

                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(height: 1)
                        .padding(.horizontal, Theme.Space.lg)

                    // Tasks section
                    if tasks.isEmpty {
                        // Empty state
                        VStack(spacing: Theme.Space.lg) {
                            Spacer().frame(height: 60)

                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Theme.Colors.textMuted)

                            Text("No tasks yet")
                                .font(Theme.Fonts.title)
                                .foregroundStyle(Theme.Colors.textSecondary)

                            Text("Add your first task below")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.xl)
                    } else {
                        VStack(spacing: 0) {
                            // Section header
                            HStack {
                                SectionLabel("Tasks", count: incompleteTasks.count)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Space.lg)
                            .padding(.top, Theme.Space.lg)
                            .padding(.bottom, Theme.Space.md)

                            // Task list
                            LazyVStack(spacing: 0) {
                                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                                    TaskItem(
                                        task: task,
                                        onDelete: { deleteTask(task) },
                                        onEdit: { taskToEdit = task }
                                    )

                                    if index < tasks.count - 1 {
                                        Divider()
                                            .background(Theme.Colors.border)
                                            .padding(.leading, 56)
                                    }
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

                InputBar(text: $inputText, onSubmit: addTask)
                    .padding(.bottom, Theme.Space.md)
                    .background(Theme.Colors.bg)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(item: $taskToEdit) { task in
            TaskEditSheet(task: task)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Actions

    private func addTask() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let parsed = parser.parse(inputText)

        let newTask = TodoItem(
            title: parsed.title,
            rawInput: inputText,
            scheduledDate: parsed.scheduledDate,
            hasSpecificTime: parsed.hasSpecificTime,
            recurrenceRule: parsed.recurrenceRule
        )

        withAnimation(.spring(response: 0.3)) {
            modelContext.insert(newTask)
            inputText = ""
        }
    }

    private func deleteTask(_ task: TodoItem) {
        withAnimation(.spring(response: 0.3)) {
            modelContext.delete(task)
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
