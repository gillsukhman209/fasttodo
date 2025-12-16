import SwiftUI

// MARK: - Task Model

struct TaskModel: Identifiable {
    let id = UUID()
    let title: String
    let time: String?
    let isRecurring: Bool
}

// MARK: - Task Item (Minimalist + Swipeable)

struct TaskItem: View {
    let task: TaskModel
    @State private var isCompleted: Bool = false
    @State private var offset: CGFloat = 0
    @State private var isSwiping: Bool = false

    private let swipeThreshold: CGFloat = 80

    var body: some View {
        ZStack(alignment: .leading) {
            // Swipe reveal background
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.success)
                        .frame(width: 32, height: 32)
                        .scaleEffect(offset > swipeThreshold / 2 ? 1 : 0.5)
                        .opacity(offset > 20 ? 1 : 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(offset > swipeThreshold / 2 ? 1 : 0)
                }
                .padding(.leading, Theme.Space.lg)

                Spacer()
            }

            // Main content
            HStack(spacing: Theme.Space.md) {
                // Tap target circle
                Button(action: completeTask) {
                    Circle()
                        .stroke(
                            isCompleted ? Theme.Colors.success : Theme.Colors.textMuted,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                        .overlay {
                            if isCompleted {
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
                        .foregroundStyle(isCompleted ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                        .strikethrough(isCompleted, color: Theme.Colors.textMuted)

                    if let time = task.time {
                        HStack(spacing: Theme.Space.xs) {
                            Text(time)
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
                        if value.translation.width > 0 && !isCompleted {
                            offset = value.translation.width
                            isSwiping = true
                        }
                    }
                    .onEnded { value in
                        if value.translation.width > swipeThreshold {
                            completeTask()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                            isSwiping = false
                        }
                    }
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
        .animation(.spring(response: 0.2), value: offset)
    }

    private func completeTask() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isCompleted.toggle()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            SectionLabel("Today", count: 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, Theme.Space.sm)

            VStack(spacing: 1) {
                TaskItem(task: TaskModel(title: "Morning workout", time: "6:30 AM", isRecurring: true))
                Divider().background(Theme.Colors.border).padding(.leading, 56)
                TaskItem(task: TaskModel(title: "Call mom", time: "7:00 PM", isRecurring: false))
                Divider().background(Theme.Colors.border).padding(.leading, 56)
                TaskItem(task: TaskModel(title: "Buy groceries", time: nil, isRecurring: false))
            }
        }
    }
}
