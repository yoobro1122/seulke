import UIKit

/// 확정/삭제류 액션에만 쓰는 짧은 햅틱. 이동/토글 같은 가벼운 탭에는 쓰지 않는다.
enum Haptics {
    enum Kind {
        case success
        case soft
        case warning
    }

    static func play(_ kind: Kind, enabled: Bool) {
        guard enabled else { return }
        switch kind {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
