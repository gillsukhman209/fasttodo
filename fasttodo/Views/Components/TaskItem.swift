import SwiftUI
import SwiftData

// MARK: - Task Item (Minimalist + Swipeable)

struct TaskItem: View {
    @Bindable var task: TodoItem
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?
    var animationIndex: Int = 0

    @State private var offset: CGFloat = 0
    @State private var isSwiping: Bool = false
    @State private var hasAppeared: Bool = false

    private let completeThreshold: CGFloat = 80
    private let deleteThreshold: CGFloat = -80

    var body: some View {
        ZStack {
            // Swipe reveal backgrounds
            HStack {
                // Complete (swipe right)
                ZStack {
                    Circle()
                        .fill(Theme.Colors.success)
                        .frame(width: 32, height: 32)
                        .scaleEffect(offset > completeThreshold / 2 ? 1 : 0.5)
                        .opacity(offset > 20 ? 1 : 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(offset > completeThreshold / 2 ? 1 : 0)
                }
                .padding(.leading, Theme.Space.lg)

                Spacer()

                // Delete (swipe left)
                ZStack {
                    Circle()
                        .fill(Theme.Colors.error)
                        .frame(width: 32, height: 32)
                        .scaleEffect(offset < deleteThreshold / 2 ? 1 : 0.5)
                        .opacity(offset < -20 ? 1 : 0)

                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(offset < deleteThreshold / 2 ? 1 : 0)
                }
                .padding(.trailing, Theme.Space.lg)
            }

            // Main content
            HStack(spacing: Theme.Space.md) {
                // Tap target circle
                Button(action: toggleComplete) {
                    Circle()
                        .stroke(
                            task.isCompleted ? Theme.Colors.success : Theme.Colors.textMuted,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                        .overlay {
                            if task.isCompleted {
                                Circle()
                                    .fill(Theme.Colors.success)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.Colors.bg)
                            }
                        }
                }
                .buttonStyle(.plain)

                // Text content
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(task.title)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(task.isCompleted ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                        .strikethrough(task.isCompleted, color: Theme.Colors.textMuted)

                    if let displayDate = task.displayDate {
                        HStack(spacing: Theme.Space.xs) {
                            Text(displayDate)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.accent)

                            if task.isRecurring {
                                Image(systemName: "repeat")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, Theme.Space.md)
            .padding(.horizontal, Theme.Space.md)
            .background(Theme.Colors.bg)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        // Allow swipe right (complete) only if not completed
                        // Allow swipe left (delete) always
                        if translation > 0 && !task.isCompleted {
                            offset = translation
                            isSwiping = true
                        } else if translation < 0 {
                            offset = translation
                            isSwiping = true
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        if translation > completeThreshold {
                            toggleComplete()
                        } else if translation < deleteThreshold {
                            deleteTask()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                            isSwiping = false
                        }
                    }
            )
            .onLongPressGesture(minimumDuration: 0.5) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onEdit?()
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: task.isCompleted)
        .animation(.spring(response: 0.2), value: offset)
        .onAppear {
            let delay = Double(animationIndex) * 0.05
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                hasAppeared = true
            }
        }
    }

    private func toggleComplete() {
        let wasCompleted = task.isCompleted
        let wasRecurring = task.isRecurring

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            task.toggleCompletion()
        }

        // Handle notifications
        if !wasCompleted {
            // Task was just completed
            if wasRecurring {
                // Recurring task: schedule notification for next occurrence
                NotificationService.shared.scheduleNotification(for: task)
            } else {
                // Non-recurring: cancel the notification
                NotificationService.shared.cancelNotification(for: task.id)
            }
        } else {
            // Task was uncompleted - reschedule notification if applicable
            NotificationService.shared.scheduleNotification(for: task)
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func deleteTask() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        onDelete?()
    }
}

// MARK: - Section Header

struct SectionLabel: View {
    let text: String
    let count: Int?

    init(_ text: String, count: Int? = nil) {
        self.text = text
        self.count = count
    }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Text(text.uppercased())
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.5)

            if let count = count {
                Text("\(count)")
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()

        VStack(spacing: 0) {
            SectionLabel("Today", count: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, Theme.Space.sm)

            VStack(spacing: 1) {
                TaskItem(task: TodoItem(
                    title: "Morning workout",
                    rawInput: "Morning workout at 6:30am",
                    scheduledDate: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()),
                    hasSpecificTime: true,
                    recurrenceRule: .daily
                ))
                Divider().background(Theme.Colors.border).padding(.leading, 56)
                TaskItem(task: TodoItem(
                    title: "Call mom",
                    rawInput: "Call mom at 7pm",
                    scheduledDate: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()),
                    hasSpecificTime: true
                ))
                Divider().background(Theme.Colors.border).padding(.leading, 56)
                TaskItem(task: TodoItem(
                    title: "Buy groceries",
                    rawInput: "Buy groceries"
                ))
            }
        }
    }
    .modelContainer(for: TodoItem.self, inMemory: true)
}
