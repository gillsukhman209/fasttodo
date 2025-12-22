import SwiftUI
import SwiftData
#if os(iOS)
import WidgetKit
import UIKit
#endif

// MARK: - Haptic Feedback Helper

func triggerHaptic(_ style: HapticStyle = .medium) {
    #if os(iOS)
    let generator: UIImpactFeedbackGenerator
    switch style {
    case .light:
        generator = UIImpactFeedbackGenerator(style: .light)
    case .medium:
        generator = UIImpactFeedbackGenerator(style: .medium)
    case .rigid:
        generator = UIImpactFeedbackGenerator(style: .rigid)
    }
    generator.impactOccurred()
    #endif
}

enum HapticStyle {
    case light, medium, rigid
}

// MARK: - Drag Handle (6 dots)

struct DragHandle: View {
    var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle()
                        .fill(isDragging ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.5))
                        .frame(width: 4, height: 4)
                    Circle()
                        .fill(isDragging ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.5))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(width: 24, height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Task Item (Minimalist + Swipeable)

struct TaskItem: View {
    @Bindable var task: TodoItem
    @Environment(\.modelContext) private var modelContext
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?
    var isDragging: Bool = false
    var dragOffset: CGFloat = 0
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    var animationIndex: Int = 0

    @State private var swipeOffset: CGFloat = 0
    @State private var isSwiping: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var gestureDirection: GestureDirection = .undetermined

    private let completeThreshold: CGFloat = 80
    private let deleteThreshold: CGFloat = -80

    private enum GestureDirection {
        case undetermined, horizontal, vertical
    }

    var body: some View {
        ZStack {
            // Swipe reveal backgrounds (hidden when dragging)
            if !isDragging {
                HStack {
                    // Toggle complete (swipe right)
                    ZStack {
                        Circle()
                            .fill(task.isCompleted ? Theme.Colors.textSecondary : Theme.Colors.success)
                            .frame(width: 32, height: 32)
                            .scaleEffect(swipeOffset > completeThreshold / 2 ? 1 : 0.5)
                            .opacity(swipeOffset > 20 ? 1 : 0)

                        Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(swipeOffset > completeThreshold / 2 ? 1 : 0)
                    }
                    .padding(.leading, Theme.Space.lg)

                    Spacer()

                    // Delete (swipe left)
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.error)
                            .frame(width: 32, height: 32)
                            .scaleEffect(swipeOffset < deleteThreshold / 2 ? 1 : 0.5)
                            .opacity(swipeOffset < -20 ? 1 : 0)

                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(swipeOffset < deleteThreshold / 2 ? 1 : 0)
                    }
                    .padding(.trailing, Theme.Space.lg)
                }
            }

            // Main content
            HStack(spacing: Theme.Space.sm) {
                // Drag handle with vertical drag gesture
                DragHandle(isDragging: isDragging)
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                onDragChanged?(value.translation.height)
                            }
                            .onEnded { _ in
                                onDragEnded?()
                            }
                    )

                // Tap target circle
                ZStack {
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleComplete()
                }

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
            .padding(.leading, Theme.Space.sm)
            .padding(.trailing, Theme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: isDragging ? 12 : 0)
                    .fill(Theme.Colors.bg)
                    .shadow(
                        color: isDragging ? Color.black.opacity(0.2) : Color.clear,
                        radius: isDragging ? 8 : 0,
                        y: isDragging ? 4 : 0
                    )
            )
            .offset(x: swipeOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Don't allow swipe while dragging (iOS only concern)
                        guard !isDragging else { return }

                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)

                        // Determine direction once at the start
                        if gestureDirection == .undetermined && (horizontal > 15 || vertical > 15) {
                            gestureDirection = horizontal > vertical * 1.5 ? .horizontal : .vertical
                        }

                        // Only handle horizontal swipes
                        guard gestureDirection == .horizontal else { return }

                        let translation = value.translation.width
                        // Allow swipe right (toggle complete) and swipe left (delete)
                        if translation > 0 || translation < 0 {
                            swipeOffset = translation
                            isSwiping = true
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        if isSwiping && gestureDirection == .horizontal {
                            if translation > completeThreshold {
                                toggleComplete()
                            } else if translation < deleteThreshold {
                                deleteTask()
                            }
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = 0
                            isSwiping = false
                        }
                        gestureDirection = .undetermined
                    }
            )
            #if os(iOS)
            .onLongPressGesture(minimumDuration: 0.5) {
                guard !isDragging else { return }
                triggerHaptic(.medium)
                onEdit?()
            }
            #endif
            #if os(macOS)
            .onTapGesture(count: 2) {
                onEdit?()
            }
            .contextMenu {
                Button("Edit") {
                    onEdit?()
                }
                Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                    toggleComplete()
                }
                Divider()
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
            }
            #endif
        }
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .opacity(isDragging ? 0.9 : (hasAppeared ? 1 : 0))
        .offset(y: calculateYOffset())
        .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: task.isCompleted)
        .animation(isDragging ? nil : .spring(response: 0.2), value: swipeOffset)
        .onAppear {
            let delay = Double(animationIndex) * 0.05
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                hasAppeared = true
            }
        }
    }

    private func calculateYOffset() -> CGFloat {
        if isDragging {
            return dragOffset
        }
        return hasAppeared ? 0 : 20
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

        // Save and refresh widget immediately
        try? modelContext.save()
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        triggerHaptic(.medium)
    }

    private func deleteTask() {
        triggerHaptic(.rigid)
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
                Divider().background(Theme.Colors.border).padding(.leading, 72)
                TaskItem(task: TodoItem(
                    title: "Call mom",
                    rawInput: "Call mom at 7pm",
                    scheduledDate: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()),
                    hasSpecificTime: true
                ))
                Divider().background(Theme.Colors.border).padding(.leading, 72)
                TaskItem(task: TodoItem(
                    title: "Buy groceries",
                    rawInput: "Buy groceries"
                ))
            }
        }
    }
    .modelContainer(for: TodoItem.self, inMemory: true)
}
