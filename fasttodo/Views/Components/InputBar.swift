import SwiftUI

struct InputBar: View {
    @Binding var text: String
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    // Detect "remind" keyword at the start
    private var isReminderDetected: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.hasPrefix("remind")
    }

    var body: some View {
        VStack(spacing: 6) {
            // Reminder badge - shows when "remind" detected
            if isReminderDetected {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                        Text("Reminder")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.blue))

                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: Theme.Space.md) {
                // Plus icon - changes to bell when reminder detected
                Circle()
                    .fill(isReminderDetected ? .blue : Theme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: isReminderDetected ? "bell.fill" : "plus")
                            .font(.system(size: isReminderDetected ? 16 : 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(!isReminderDetected && (isFocused || !text.isEmpty) ? 45 : 0))
                    }
                    .shadow(color: (isReminderDetected ? Color.blue : Theme.Colors.accent).opacity(0.4), radius: 8, y: 4)
                    .onTapGesture {
                        if !text.isEmpty {
                            submitAction()
                        } else {
                            isFocused = true
                        }
                    }

                // Text field
                TextField("Add a task...", text: $text)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(submitAction)

                // Clear/Submit
                if !text.isEmpty {
                    Button(action: submitAction) {
                        Text("Add")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.sm)
                            .background {
                                Capsule()
                                    .fill(isReminderDetected ? .blue : Theme.Colors.accent)
                            }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.bgSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .stroke(isReminderDetected ? Color.blue.opacity(0.5) : (isFocused ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.border), lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .animation(.spring(response: 0.3), value: isFocused)
        .animation(.spring(response: 0.3), value: text.isEmpty)
        .animation(.spring(response: 0.3), value: isReminderDetected)
        .onChange(of: AppState.shared.shouldFocusInput) { _, shouldFocus in
            if shouldFocus {
                isFocused = true
                AppState.shared.shouldFocusInput = false
            }
        }
        .onAppear {
            if AppState.shared.shouldFocusInput {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                    AppState.shared.shouldFocusInput = false
                }
            }
        }
    }

    private func submitAction() {
        guard !text.isEmpty else { return }
        onSubmit?()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Re-focus after a brief delay to keep keyboard open
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()
        VStack {
            Spacer()
            InputBar(text: .constant(""))
                .padding(.bottom, 20)
        }
    }
}
