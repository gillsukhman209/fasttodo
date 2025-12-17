import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.sortOrder, order: .reverse) private var tasks: [TodoItem]

    @State private var inputText: String = ""
    @State private var isDarkMode: Bool = true
    @State private var taskToEdit: TodoItem?
    @State private var showUndoToast: Bool = false
    @State private var pendingDeleteTask: TodoItem?
    @State private var showCelebration: Bool = false
    @State private var previousIncompleteCount: Int = 0
    @State private var draggingTask: TodoItem?

    private let parser = NaturalLanguageParser()

    // Filter for today's tasks only (no date, today, or overdue)
    private var todayTasks: [TodoItem] {
        let calendar = Calendar.current
        let now = Date()
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)

        return tasks.filter { task in
            // No scheduled date = inbox/today task
            guard let date = task.scheduledDate else { return true }
            // Today or overdue (before tomorrow)
            return date < startOfTomorrow
        }
    }

    // Computed properties for stats
    private var completedCount: Int {
        todayTasks.filter { $0.isCompleted }.count
    }

    private var incompleteTasks: [TodoItem] {
        todayTasks.filter { !$0.isCompleted && $0.id != pendingDeleteTask?.id }
    }

    private var visibleTasks: [TodoItem] {
        todayTasks.filter { $0.id != pendingDeleteTask?.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HeaderView(completed: completedCount, total: todayTasks.count, isDarkMode: $isDarkMode)

                // Divider
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 1)
                    .padding(.horizontal, Theme.Space.lg)

                // Tasks section
                if visibleTasks.isEmpty {
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
                            ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                                TaskItem(
                                    task: task,
                                    onDelete: { deleteTask(task) },
                                    onEdit: { taskToEdit = task },
                                    onDragStart: { draggingTask = task },
                                    animationIndex: index
                                )
                                .opacity(draggingTask?.id == task.id ? 0.5 : 1)
                                .onDrop(of: [.text], delegate: TaskDropDelegate(
                                    task: task,
                                    tasks: visibleTasks,
                                    draggingTask: $draggingTask,
                                    reorderAction: reorderTasks
                                ))

                                if index < visibleTasks.count - 1 {
                                    Divider()
                                        .background(Theme.Colors.border)
                                        .padding(.leading, 72)
                                }
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // Undo toast
                if showUndoToast, let taskId = pendingDeleteTask?.id {
                    UndoToast(
                        message: "Task deleted",
                        taskId: taskId,
                        onUndo: undoDelete,
                        onDismiss: confirmDelete
                    )
                    .id(taskId)
                    .padding(.bottom, Theme.Space.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                InputBar(text: $inputText, onSubmit: addTask)
                    .padding(.bottom, Theme.Space.md)
            }
            .background {
                Rectangle()
                    .fill(Theme.Colors.bg)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Theme.Colors.bg)
        .animation(.easeInOut(duration: 0.3), value: isDarkMode)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(item: $taskToEdit) { task in
            TaskEditSheet(task: task)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if showCelebration {
                CelebrationView {
                    withAnimation {
                        showCelebration = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: incompleteTasks.count) { oldValue, newValue in
            // Celebrate when going from >0 to 0 incomplete tasks
            if oldValue > 0 && newValue == 0 && !todayTasks.isEmpty {
                withAnimation {
                    showCelebration = true
                }
            }
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

        // Schedule notification if task has specific time
        NotificationService.shared.scheduleNotification(for: newTask)
    }

    private func deleteTask(_ task: TodoItem) {
        // If there's already a pending delete, confirm it first
        if let existingTask = pendingDeleteTask {
            NotificationService.shared.cancelNotification(for: existingTask.id)
            modelContext.delete(existingTask)
        }

        // Store new task for potential undo
        pendingDeleteTask = task

        // Show the toast
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func reorderTasks(from source: TodoItem, to destination: TodoItem) {
        guard source.id != destination.id else { return }

        let sourceIndex = visibleTasks.firstIndex(where: { $0.id == source.id })
        let destIndex = visibleTasks.firstIndex(where: { $0.id == destination.id })

        guard let sourceIdx = sourceIndex, let destIdx = destIndex else { return }

        // Swap sort orders
        let sourceSortOrder = source.sortOrder
        source.sortOrder = destination.sortOrder
        destination.sortOrder = sourceSortOrder

        // If moving to adjacent position, we're done
        // For non-adjacent moves, shift all items between
        if abs(sourceIdx - destIdx) > 1 {
            let range = sourceIdx < destIdx
                ? (sourceIdx + 1)...destIdx
                : destIdx...(sourceIdx - 1)

            for i in range {
                if sourceIdx < destIdx {
                    visibleTasks[i].sortOrder += 1
                } else {
                    visibleTasks[i].sortOrder -= 1
                }
            }
        }
    }
}

// MARK: - Drop Delegate

struct TaskDropDelegate: DropDelegate {
    let task: TodoItem
    let tasks: [TodoItem]
    @Binding var draggingTask: TodoItem?
    let reorderAction: (TodoItem, TodoItem) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingTask = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingTask, dragging.id != task.id else { return }
        reorderAction(dragging, task)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // Optional: handle exit
    }
}

#Preview {
    TodayView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
