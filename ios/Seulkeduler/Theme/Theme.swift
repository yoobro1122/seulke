import SwiftUI

// LocalSeulColors 이식: 팔레트를 SwiftUI Environment 값으로 내려준다.
private struct SeulPaletteKey: EnvironmentKey {
    static let defaultValue: SeulPalette = ThemeCatalog.mono
}

extension EnvironmentValues {
    var seul: SeulPalette {
        get { self[SeulPaletteKey.self] }
        set { self[SeulPaletteKey.self] = newValue }
    }
}

/// 코너 반경 토큰(pill/small/medium/large/scheduleBlock)
enum Radius {
    static let small: CGFloat = 14
    static let medium: CGFloat = 22
    static let large: CGFloat = 28
    static let scheduleBlock: CGFloat = 18
}

/// 최소 터치 영역(보이는 크기와 별개로 히트 영역만 확대)
enum Touch {
    static let min: CGFloat = 44
}

/// 위쪽 두 모서리만 둥근 모양(바텀시트)
struct TopRoundedShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
