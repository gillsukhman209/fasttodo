import SwiftUI
#if os(iOS)
import UIKit
#endif

struct UndoToast: View {
    let message: String
    let taskId: UUID  // Track which task this toast is for
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible: Bool = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Text(message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Button(action: {
                dismissTask?.cancel()
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onUndo()
            }) {
                Text("Undo")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Colors.bgSecondary)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        }
        .padding(.horizontal, Theme.Space.lg)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto dismiss after 3 seconds
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()

        VStack {
            Spacer()
            UndoToast(
                message: "Task deleted",
                taskId: UUID(),
                onUndo: { print("Undo tapped") },
                onDismiss: { print("Dismissed") }
            )
            .padding(.bottom, 100)
        }
    }
}
