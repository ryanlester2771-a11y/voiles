import SwiftUI

/// Coaching overlay view to guide users in scanning the room
struct CoachingOverlayView: View {
    let message: String?

    @State private var animationPhase = 0.0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Animated scanning indicator
                ScanningAnimation(phase: animationPhase)
                    .frame(width: 200, height: 200)

                VStack(spacing: 16) {
                    Text("Scanning Room")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text(message ?? "Move your iPad slowly to detect walls")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Tips
                VStack(alignment: .leading, spacing: 12) {
                    TipRow(icon: "light.max", text: "Ensure good lighting")
                    TipRow(icon: "move.3d", text: "Move slowly and steadily")
                    TipRow(icon: "square.dashed", text: "Point at walls with texture")
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
    }
}

// MARK: - Scanning Animation

struct ScanningAnimation: View {
    let phase: Double

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)

            // Animated arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    AngularGradient(
                        colors: [.blue.opacity(0), .blue],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(phase * 360))

            // Inner content
            VStack(spacing: 8) {
                Image(systemName: "ipad.landscape")
                    .font(.system(size: 48))
                    .foregroundColor(.white)

                Image(systemName: "arrow.left.and.right")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Corner brackets
            ForEach(0..<4, id: \.self) { index in
                CornerBracket()
                    .rotationEffect(.degrees(Double(index) * 90))
                    .offset(x: 70, y: 0)
                    .rotationEffect(.degrees(Double(index) * 90))
            }
        }
    }
}

// MARK: - Corner Bracket

struct CornerBracket: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
    }
}

#Preview {
    CoachingOverlayView(message: nil)
}
