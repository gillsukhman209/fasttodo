import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Header with Progress

struct HeaderView: View {
    let completed: Int
    let total: Int
    @Binding var isDarkMode: Bool
    var onSync: (() -> Void)? = nil

    @State private var isSyncing: Bool = false

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private var remaining: Int {
        max(0, total - completed)
    }

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            // Top bar with theme toggle
            HStack {
                // Date
                Text(Date(), format: .dateTime.weekday(.wide))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                // Sync button
                if onSync != nil {
                    Button(action: triggerSync) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .rotationEffect(.degrees(isSyncing ? 360 : 0))
                            .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, Theme.Space.md)
                }

                // Theme toggle
                Button(action: toggleTheme) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.full)
                            .fill(Theme.Colors.bgSecondary)
                            .frame(width: 56, height: 32)

                        HStack(spacing: 0) {
                            Circle()
                                .fill(isDarkMode ? Theme.Colors.bg : Theme.Colors.accent)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isDarkMode ? Theme.Colors.accent : .white)
                                }
                                .offset(x: isDarkMode ? 11 : -11)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Main hero section
            HStack(alignment: .top, spacing: Theme.Space.lg) {
                // Left: Big number
                VStack(alignment: .leading, spacing: -4) {
                    Text("\(remaining)")
                        .font(Theme.Fonts.mega)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("tasks left")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                // Right: Progress ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(Theme.Colors.bgTertiary, lineWidth: 8)

                    // Progress
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Theme.Colors.accent,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                    // Center text
                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))")
                            .font(Theme.Fonts.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("%")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(width: 80, height: 80)
            }

            // Motivational message based on progress
            HStack(spacing: Theme.Space.sm) {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 8, height: 8)

                Text(motivationalMessage)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Space.lg)
    }

    private var motivationalMessage: String {
        switch progress {
        case 0: return "Let's get started!"
        case 0..<0.25: return "Good start, keep going"
        case 0.25..<0.5: return "You're making progress"
        case 0.5..<0.75: return "Halfway there!"
        case 0.75..<1: return "Almost done, finish strong"
        default: return "All done! Great job"
        }
    }

    private func toggleTheme() {
        withAnimation(.spring(response: 0.3)) {
            isDarkMode.toggle()
            ThemeManager.shared.isDarkMode = isDarkMode
        }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func triggerSync() {
        guard !isSyncing else { return }
        isSyncing = true
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        onSync?()
        // Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSyncing = false
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()
        HeaderView(completed: 3, total: 7, isDarkMode: .constant(true))
    }
}
