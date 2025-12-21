import SwiftUI
#if os(iOS)
import UIKit
#endif

struct InputBar: View {
    @Binding var text: String
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            // Plus icon
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isFocused || !text.isEmpty ? 45 : 0))
                }
                .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 8, y: 4)
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
                .textFieldStyle(.plain)
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
                                .fill(Theme.Colors.accent)
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
                #if os(iOS)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(isFocused ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.border, lineWidth: 1)
                }
                #endif
        }
        .padding(.horizontal, Theme.Space.md)
        .animation(.spring(response: 0.3), value: isFocused)
        .animation(.spring(response: 0.3), value: text.isEmpty)
    }

    private func submitAction() {
        guard !text.isEmpty else { return }
        onSubmit?()
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Re-focus after a brief delay to keep keyboard open
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
        #endif
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
