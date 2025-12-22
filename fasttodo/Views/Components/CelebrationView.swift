import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CelebrationView: View {
    @State private var particles: [Particle] = []
    @State private var showMessage: Bool = false

    let onDismiss: () -> Void

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let color: Color
        let size: CGFloat
        var rotation: Double
        var velocity: CGFloat
        var horizontalVelocity: CGFloat
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Confetti particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
            }

            // Celebration message
            VStack(spacing: Theme.Space.md) {
                Text("🎉")
                    .font(.system(size: 64))

                Text("All done!")
                    .font(Theme.Fonts.large)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("You crushed it today")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Space.xl)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.bg)
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
            }
            .scaleEffect(showMessage ? 1 : 0.5)
            .opacity(showMessage ? 1 : 0)
        }
        .onAppear {
            startCelebration()
        }
    }

    private func startCelebration() {
        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        // Create particles
        let colors: [Color] = [
            Theme.Colors.accent,
            Theme.Colors.success,
            Color(hex: "FFD700"), // Gold
            Color(hex: "FF69B4"), // Pink
            Color(hex: "00CED1"), // Cyan
        ]

        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        #elseif os(macOS)
        let screenWidth = NSScreen.main?.frame.width ?? 800
        let screenHeight = NSScreen.main?.frame.height ?? 600
        #endif

        for _ in 0..<50 {
            let particle = Particle(
                x: CGFloat.random(in: 0...screenWidth),
                y: -20,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                velocity: CGFloat.random(in: 3...7),
                horizontalVelocity: CGFloat.random(in: -2...2)
            )
            particles.append(particle)
        }

        // Animate particles
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            for i in particles.indices {
                particles[i].y += particles[i].velocity
                particles[i].x += particles[i].horizontalVelocity
                particles[i].rotation += Double.random(in: -5...5)

                // Stop when off screen
                if particles[i].y > screenHeight + 50 {
                    timer.invalidate()
                }
            }
        }

        // Show message with delay
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
            showMessage = true
        }

        // Auto dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            onDismiss()
        }
    }
}

#Preview {
    CelebrationView(onDismiss: {})
}
