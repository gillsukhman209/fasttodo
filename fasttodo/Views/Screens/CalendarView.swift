import SwiftUI
import SwiftData
#if os(iOS)
import WidgetKit
import UIKit
#endif

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.scheduledDate, order: .forward) private var allTasks: [TodoItem]

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    @State private var taskToEdit: TodoItem? = nil
    @State private var showAddSheet: Bool = false
    @State private var showUndoToast: Bool = false
    @State private var pendingDeleteTask: TodoItem? = nil
    @State private var isSyncing: Bool = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: - Computed

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var weeksInMonth: [[Date?]] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1 = Sunday

        var allDays: [Date?] = []

        // Leading empty cells
        for _ in 0..<(firstWeekday - 1) {
            allDays.append(nil)
        }

        // Actual days
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            allDays.append(date)
        }

        // Trailing empty cells to complete the last week
        while allDays.count % 7 != 0 {
            allDays.append(nil)
        }

        // Split into weeks
        return stride(from: 0, to: allDays.count, by: 7).map {
            Array(allDays[$0..<min($0 + 7, allDays.count)])
        }
    }

    private func tasksFor(date: Date) -> [TodoItem] {
        allTasks.filter { task in
            guard let scheduled = task.scheduledDate else { return false }
            guard task.id != pendingDeleteTask?.id else { return false }
            return calendar.isDate(scheduled, inSameDayAs: date)
        }
    }

    private var selectedDateTasks: [TodoItem] {
        guard let date = selectedDate else { return [] }
        return tasksFor(date: date)
    }

    private var selectedIncompleteTasks: [TodoItem] {
        selectedDateTasks.filter { !$0.isCompleted }
    }

    private var selectedCompletedTasks: [TodoItem] {
        selectedDateTasks.filter { $0.isCompleted }
    }

    // Monthly stats
    private var monthTasks: [TodoItem] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        let firstOfMonth = calendar.date(from: comps)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth)!

        return allTasks.filter { task in
            guard let date = task.scheduledDate else { return false }
            return date >= firstOfMonth && date < nextMonth
        }
    }

    private var monthCompletedCount: Int {
        monthTasks.filter { $0.isCompleted }.count
    }

    private var monthPendingCount: Int {
        monthTasks.filter { !$0.isCompleted }.count
    }

    // Streak
    private var completionStreak: Int {
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        let todayTasks = tasksFor(date: today)
        if !todayTasks.isEmpty && todayTasks.allSatisfy({ $0.isCompleted }) {
            streak += 1
        }

        checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        for _ in 0..<365 {
            let dayTasks = tasksFor(date: checkDate)
            if dayTasks.isEmpty {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                continue
            }
            if dayTasks.allSatisfy({ $0.isCompleted }) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    private func isOverdue(date: Date) -> Bool {
        let startOfToday = calendar.startOfDay(for: Date())
        return date < startOfToday && tasksFor(date: date).contains { !$0.isCompleted }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    monthNavigation
                    dayOfWeekHeader
                    calendarGrid
                    monthStatsSection

                    if selectedDate != nil {
                        selectedDateSection
                    }

                    Spacer().frame(height: 120)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { syncData() }

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
                    .id(taskId)
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
        .sheet(isPresented: $showAddSheet) {
            if let date = selectedDate {
                QuickAddSheet(targetDate: date)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Calendar")
                        .font(Theme.Fonts.large)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    if completionStreak > 0 {
                        HStack(spacing: Theme.Space.xs) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.accent)
                            Text("\(completionStreak) day streak")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }

                Spacer()

                Button(action: triggerSync) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                        .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.md)
        }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle().fill(Theme.Colors.bgSecondary)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            if !calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Date()
                        selectedDate = calendar.startOfDay(for: Date())
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            Capsule().fill(Theme.Colors.accent.opacity(0.15))
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle().fill(Theme.Colors.bgSecondary)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.bottom, Theme.Space.md)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
                        }
                    } else if value.translation.width > 50 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
                        }
                    }
                }
        )
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        HStack(spacing: 4) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, 6)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            ForEach(Array(weeksInMonth.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if let date = week[dayIndex] {
                            let dayTasks = tasksFor(date: date)
                            let isToday = calendar.isDateInToday(date)
                            let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                            let overdue = isOverdue(date: date)

                            CalendarDayCell(
                                date: date,
                                isToday: isToday,
                                isSelected: isSelected,
                                tasks: dayTasks,
                                isOverdue: overdue
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if isSelected {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = date
                                    }
                                }
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                        } else {
                            // Empty cell for days outside the month
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity)
                                .frame(height: 88)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Space.md)
    }

    // MARK: - Month Stats

    private var monthStatsSection: some View {
        HStack(spacing: Theme.Space.sm) {
            StatPill(value: monthTasks.count, label: "Total", color: Theme.Colors.textSecondary)
            StatPill(value: monthCompletedCount, label: "Done", color: Theme.Colors.success)
            StatPill(value: monthPendingCount, label: "Pending", color: Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, Theme.Space.lg)
    }

    // MARK: - Selected Date Section

    private var selectedDateSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(selectedDateTitle)
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(selectedDateSubtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.md)

            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 1)
                .padding(.horizontal, Theme.Space.lg)

            if selectedDateTasks.isEmpty {
                VStack(spacing: Theme.Space.md) {
                    Spacer().frame(height: Theme.Space.xl)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.Colors.textMuted)

                    Text("No tasks for this day")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Button {
                        showAddSheet = true
                    } label: {
                        Text("Add a task")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().stroke(Theme.Colors.accent, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: Theme.Space.lg)
                }
                .frame(maxWidth: .infinity)
            } else {
                if !selectedIncompleteTasks.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            SectionLabel("Pending", count: selectedIncompleteTasks.count)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.md)
                        .padding(.bottom, Theme.Space.sm)

                        ForEach(Array(selectedIncompleteTasks.enumerated()), id: \.element.id) { index, task in
                            TaskItem(
                                task: task,
                                onDelete: { deleteTask(task) },
                                onEdit: { taskToEdit = task },
                                animationIndex: index
                            )
                            if index < selectedIncompleteTasks.count - 1 {
                                Divider()
                                    .background(Theme.Colors.border)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }

                if !selectedCompletedTasks.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            SectionLabel("Completed", count: selectedCompletedTasks.count)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.md)
                        .padding(.bottom, Theme.Space.sm)

                        ForEach(Array(selectedCompletedTasks.enumerated()), id: \.element.id) { index, task in
                            TaskItem(
                                task: task,
                                onDelete: { deleteTask(task) },
                                onEdit: { taskToEdit = task },
                                animationIndex: index
                            )
                            if index < selectedCompletedTasks.count - 1 {
                                Divider()
                                    .background(Theme.Colors.border)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedDateTitle: String {
        guard let date = selectedDate else { return "" }
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var selectedDateSubtitle: String {
        let tasks = selectedDateTasks
        if tasks.isEmpty { return "Free day" }
        let completed = tasks.filter { $0.isCompleted }.count
        let total = tasks.count
        if completed == total { return "All \(total) tasks completed" }
        return "\(completed)/\(total) completed"
    }

    // MARK: - Actions

    private func syncData() {
        Task {
            await FirebaseSyncService.shared.syncAllTodos(Array(allTasks))
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    private func triggerSync() {
        guard !isSyncing else { return }
        isSyncing = true
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        syncData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSyncing = false
        }
    }

    private func deleteTask(_ task: TodoItem) {
        if let existingTask = pendingDeleteTask {
            NotificationService.shared.cancelNotification(for: existingTask.id)
            modelContext.delete(existingTask)
            try? modelContext.save()
        }

        FirebaseSyncService.shared.deleteTodo(task)
        NotificationService.shared.cancelNotification(for: task.id)

        pendingDeleteTask = task
        withAnimation(.spring(response: 0.3)) {
            showUndoToast = true
        }
    }

    private func undoDelete() {
        if let task = pendingDeleteTask {
            FirebaseSyncService.shared.pushTodo(task)
            NotificationService.shared.scheduleNotification(for: task)
        }
        withAnimation(.spring(response: 0.3)) {
            pendingDeleteTask = nil
            showUndoToast = false
        }
    }

    private func confirmDelete() {
        if let task = pendingDeleteTask {
            withAnimation(.spring(response: 0.3)) {
                modelContext.delete(task)
                pendingDeleteTask = nil
                showUndoToast = false
            }
            try? modelContext.save()
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let tasks: [TodoItem]
    let isOverdue: Bool

    private let calendar = Calendar.current
    private let maxVisible = 2 // Max task titles shown in cell

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var incompleteTasks: [TodoItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TodoItem] {
        tasks.filter { $0.isCompleted }
    }

    private var allDone: Bool {
        !tasks.isEmpty && incompleteTasks.isEmpty
    }

    private var borderColor: Color {
        if isSelected { return Theme.Colors.accent }
        if isToday { return Theme.Colors.accent.opacity(0.6) }
        return Theme.Colors.border
    }

    private var bgColor: Color {
        if isSelected { return Theme.Colors.accent.opacity(0.08) }
        if allDone { return Theme.Colors.success.opacity(0.05) }
        if isOverdue { return Theme.Colors.error.opacity(0.05) }
        return Color.clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Day number
            HStack {
                if isToday {
                    Text(dayNumber)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background {
                            Circle().fill(Theme.Colors.accent)
                        }
                } else {
                    Text(dayNumber)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(dayNumberColor)
                        .padding(.leading, 2)
                }

                Spacer()

                if tasks.count > maxVisible {
                    Text("+\(tasks.count - maxVisible)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.trailing, 2)
                }
            }

            // Task titles inside the cell
            if tasks.isEmpty {
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(tasks.prefix(maxVisible).enumerated()), id: \.element.id) { _, task in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(taskDotColor(task))
                                .frame(width: 4, height: 4)

                            Text(task.title)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(task.isCompleted ? Theme.Colors.textMuted : Theme.Colors.textSecondary)
                                .strikethrough(task.isCompleted, color: Theme.Colors.textMuted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 88)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected || isToday ? 1.5 : 0.5)
        }
    }

    private var dayNumberColor: Color {
        if isOverdue { return Theme.Colors.error }
        if isSelected { return Theme.Colors.accent }
        return Theme.Colors.textPrimary
    }

    private func taskDotColor(_ task: TodoItem) -> Color {
        if task.isCompleted { return Theme.Colors.success }
        if isOverdue { return Theme.Colors.error }
        return Theme.Colors.accent
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            Text("\(value)")
                .font(Theme.Fonts.title)
                .foregroundStyle(color)

            Text(label.uppercased())
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.Colors.bgSecondary)
        }
    }
}

// MARK: - Quick Add Sheet

struct QuickAddSheet: View {
    let targetDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var inputText: String = ""
    @State private var hasTime: Bool = false
    @State private var selectedTime: Date = Date()

    private var dateTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(targetDate) { return "Today" }
        if calendar.isDateInTomorrow(targetDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: targetDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()

                VStack(spacing: Theme.Space.lg) {
                    // Date display
                    HStack(spacing: Theme.Space.md) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Theme.Colors.accent)
                        Text(dateTitle)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(Theme.Space.md)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(Theme.Colors.bgSecondary)
                    }

                    // Task title input
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("TASK")
                            .font(Theme.Fonts.micro)
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.5)

                        TextField("What needs to be done?", text: $inputText)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(Theme.Space.md)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Colors.bgSecondary)
                            }
                            .onSubmit { addTask() }
                    }

                    // Optional time
                    Toggle(isOn: $hasTime) {
                        HStack(spacing: Theme.Space.md) {
                            Image(systemName: "clock")
                                .foregroundStyle(Theme.Colors.accent)
                            Text("Set a time")
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                    }
                    .tint(Theme.Colors.accent)
                    .padding(Theme.Space.md)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(Theme.Colors.bgSecondary)
                    }

                    if hasTime {
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        #if os(iOS)
                        .datePickerStyle(.wheel)
                        #endif
                        .labelsHidden()
                        .tint(Theme.Colors.accent)
                        .padding(Theme.Space.md)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Theme.Colors.bgSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(Theme.Space.lg)
            }
            .navigationTitle("Add Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTask() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.textMuted : Theme.Colors.accent)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func addTask() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let calendar = Calendar.current
        var scheduledDate = targetDate

        if hasTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
            scheduledDate = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                          minute: timeComponents.minute ?? 0,
                                          second: 0,
                                          of: targetDate) ?? targetDate
        }

        let newTask = TodoItem(
            title: trimmed,
            rawInput: trimmed,
            scheduledDate: scheduledDate,
            hasSpecificTime: hasTime
        )

        modelContext.insert(newTask)
        NotificationService.shared.scheduleNotification(for: newTask)
        try? modelContext.save()
        FirebaseSyncService.shared.pushTodo(newTask)

        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        dismiss()
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
