import SwiftUI
import SwiftData

struct UpcomingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.scheduledDate, order: .forward) private var allTasks: [TodoItem]

    @State private var taskToEdit: TodoItem?
    @State private var showUndoToast: Bool = false
    @State private var pendingDeleteTask: TodoItem?

    // Filter for future tasks only
    private var upcomingTasks: [TodoItem] {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)

        return allTasks.filter { task in
            guard let date = task.scheduledDate else { return false }
            guard task.id != pendingDeleteTask?.id else { return false }
            return date >= startOfTomorrow
        }
    }

    // Group tasks by date section
    private var groupedTasks: [(title: String, tasks: [TodoItem])] {
        let calendar = Calendar.current
        let today = Date()

        var tomorrow: [TodoItem] = []
        var thisWeek: [TodoItem] = []
        var later: [TodoItem] = []

        for task in upcomingTasks {
            guard let date = task.scheduledDate else { continue }

            if calendar.isDateInTomorrow(date) {
                tomorrow.append(task)
            } else if let weekEnd = calendar.date(byAdding: .day, value: 7, to: today),
                      date < weekEnd {
                thisWeek.append(task)
            } else {
                later.append(task)
            }
        }

        var result: [(title: String, tasks: [TodoItem])] = []
        if !tomorrow.isEmpty { result.append(("Tomorrow", tomorrow)) }
        if !thisWeek.isEmpty { result.append(("This Week", thisWeek)) }
        if !later.isEmpty { result.append(("Later", later)) }

        return result
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Theme.Colors.bg
                .ignoresSafeArea()

            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("Upcoming")
                            .font(Theme.Fonts.large)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("\(upcomingTasks.count) scheduled")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.xl)
                    .padding(.bottom, Theme.Space.lg)

                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(height: 1)
                        .padding(.horizontal, Theme.Space.lg)

                    if upcomingTasks.isEmpty {
                        // Empty state
                        VStack(spacing: Theme.Space.lg) {
                            Spacer().frame(height: 60)

                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Theme.Colors.textMuted)

                            Text("No upcoming tasks")
                                .font(Theme.Fonts.title)
                                .foregroundStyle(Theme.Colors.textSecondary)

                            Text("Tasks scheduled for future dates\nwill appear here")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.xl)
                    } else {
                        // Grouped task sections
                        VStack(spacing: Theme.Space.lg) {
                            ForEach(groupedTasks, id: \.title) { section in
                                VStack(spacing: 0) {
                                    // Section header
                                    HStack {
                                        SectionLabel(section.title, count: section.tasks.count)
                                        Spacer()
                                    }
                                    .padding(.horizontal, Theme.Space.lg)
                                    .padding(.top, Theme.Space.lg)
                                    .padding(.bottom, Theme.Space.md)

                                    // Tasks in section
                                    LazyVStack(spacing: 0) {
                                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                                            TaskItem(
                                                task: task,
                                                onDelete: { deleteTask(task) },
                                                onEdit: { taskToEdit = task },
                                                animationIndex: index
                                            )

                                            if index < section.tasks.count - 1 {
                                                Divider()
                                                    .background(Theme.Colors.border)
                                                    .padding(.leading, 56)
                                            }
                                        }
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

            // Undo toast
            if showUndoToast, let taskId = pendingDeleteTask?.id {
                VStack {
                    Spacer()
                    UndoToast(
                        message: "Task deleted",
                        taskId: taskId,
                        onUndo: undoDelete,
                        onDismiss: confirmDelete
                    )
                    .id(taskId)  // Force new instance for each delete
                    .padding(.bottom, Theme.Space.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $taskToEdit) { task in
            TaskEditSheet(task: task)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Actions

    private func deleteTask(_ task: TodoItem) {
        pendingDeleteTask = task
        withAnimation(.spring(response: 0.3)) {
            showUndoToast = true
        }
    }

    private func undoDelete() {
        withAnimation(.spring(response: 0.3)) {
            pendingDeleteTask = nil
            showUndoToast = false
        }
    }

    private func confirmDelete() {
        if let task = pendingDeleteTask {
            // Cancel any scheduled notification
            NotificationService.shared.cancelNotification(for: task.id)

            withAnimation(.spring(response: 0.3)) {
                modelContext.delete(task)
                pendingDeleteTask = nil
                showUndoToast = false
            }
        }
    }
}

#Preview {
    UpcomingView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
