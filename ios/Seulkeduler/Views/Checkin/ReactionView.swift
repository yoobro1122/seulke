import SwiftUI

/// 체크인 확정 리액션(안드로이드 Lottie 대체, SwiftUI 네이티브 애니메이션).
/// 성공 = 오버슈트 바운스 + 컨페티 / 실패 = 톤다운된 처짐 후 복귀. 재생이 끝나면 onFinish.
struct ReactionView: View {
    enum Kind: Equatable {
        case success, fail
    }

    @Environment(\.seul) private var c
    let kind: Kind
    var onFinish: () -> Void

    @State private var scale: CGFloat = 0.2
    @State private var droop: CGFloat = 0
    @State private var tilt: Double = 0
    @State private var burst = false
    @State private var fadeOut = false

    private static let pieces: [(angle: Double, distance: CGFloat, size: CGFloat, spin: Double, color: Int)] =
        (0..<22).map { i in
            let angle = Double(i) / 22 * 360 + Double((i * 37) % 17)
            return (angle, CGFloat(70 + (i * 29) % 50), CGFloat(6 + (i * 7) % 5), Double((i * 53) % 360), i % 7)
        }

    var body: some View {
        ZStack {
            if kind == .success {
                ForEach(0..<Self.pieces.count, id: \.self) { i in
                    let p = Self.pieces[i]
                    let rad = p.angle * .pi / 180
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(c.swatches[p.color].lighter(0.15).color)
                        .frame(width: p.size, height: p.size * 1.6)
                        .rotationEffect(.degrees(burst ? p.spin + 180 : p.spin))
                        .offset(x: burst ? CGFloat(cos(rad)) * p.distance : 0,
                                y: burst ? CGFloat(sin(rad)) * p.distance + 30 : 0)
                        .opacity(burst ? 0 : 1)
                }
            }

            Circle()
                .fill(kind == .success ? AnyShapeStyle(c.accentGradient) : AnyShapeStyle(c.inkFaint.muted(0.3).color))
                .frame(width: 104, height: 104)
                .overlay(
                    Image(systemName: kind == .success ? "checkmark" : "cloud.drizzle")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .scaleEffect(scale)
                .offset(y: droop)
                .rotationEffect(.degrees(tilt))

            Text(kind == .success ? "잘했어요!" : "괜찮아요, 다음에 해봐요")
                .font(SeulFont.medium(16))
                .foregroundColor(kind == .success ? c.ink.color : c.inkSoft.color)
                .offset(y: 90)
                .opacity(scale > 0.5 ? 1 : 0)
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear(perform: play)
    }

    private func play() {
        switch kind {
        case .success:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.45)) { scale = 1 }
            withAnimation(.easeOut(duration: 0.9).delay(0.12)) { burst = true }
        case .fail:
            withAnimation(.easeOut(duration: 0.3)) { scale = 0.92 }
            withAnimation(.easeIn(duration: 0.35).delay(0.2)) {
                droop = 16
                tilt = -7
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
                droop = 0
                tilt = 0
                scale = 1
            }
        }
        withAnimation(.easeIn(duration: 0.2).delay(1.35)) { fadeOut = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onFinish() }
    }
}
