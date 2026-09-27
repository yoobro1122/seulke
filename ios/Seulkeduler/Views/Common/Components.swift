import SwiftUI

// MARK: - 버튼

/// 톤온톤 그라데이션 주 버튼("완료했어요", "저장" 등)
struct PrimaryButton: View {
    @Environment(\.seul) private var c
    let title: String
    var tint: HSB?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SeulFont.medium(16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(c.toneGradient(tint ?? c.accent)))
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecondaryButton: View {
    @Environment(\.seul) private var c
    let title: String
    var destructive = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SeulFont.medium(16))
                .foregroundColor(destructive ? Color.red.opacity(0.85) : c.ink.color)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .stroke(c.line.color, lineWidth: 1.2))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 아이콘 전용 원형 버튼(히트 영역 44pt)
struct IconButton: View {
    @Environment(\.seul) private var c
    let symbol: String
    var filled = false
    var label: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(filled ? .white : c.ink.color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(filled ? AnyShapeStyle(c.accentGradient) : AnyShapeStyle(c.surfaceAlt.color)))
                .frame(width: Touch.min, height: Touch.min)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label ?? symbol)
    }
}

// MARK: - 칩 / 태그

struct Chip: View {
    @Environment(\.seul) private var c
    let title: String
    var symbol: String?
    var selected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol = symbol {
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                Text(title).font(SeulFont.medium(14))
            }
            .foregroundColor(selected ? .white : c.ink.color)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(selected ? AnyShapeStyle(c.accentGradient) : AnyShapeStyle(c.surfaceAlt.color)))
            .frame(minHeight: Touch.min)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

struct PillTag: View {
    @Environment(\.seul) private var c
    let text: String
    var strong = false

    var body: some View {
        Text(text)
            .font(SeulFont.monoMedium(11))
            .foregroundColor(strong ? .white : c.inkSoft.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(strong ? c.accent.color : c.surfaceAlt.color))
    }
}

// MARK: - 별(중요도)

struct StarsView: View {
    @Environment(\.seul) private var c
    let value: Int
    var size: CGFloat = 11
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: onSelect == nil ? 1 : 4) {
            ForEach(1...5, id: \.self) { i in
                let star = Image(systemName: i <= value ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold, design: .rounded))
                    .foregroundColor(i <= value ? c.accent.color : c.inkFaint.color)
                if let onSelect = onSelect {
                    Button { onSelect(i) } label: {
                        star.frame(width: Touch.min, height: Touch.min).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    star
                }
            }
        }
    }
}

// MARK: - 섹션

struct SectionLabel: View {
    @Environment(\.seul) private var c
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(SeulFont.mono(11))
            .foregroundColor(c.inkSoft.color)
            .tracking(0.6)
    }
}

struct Card<Content: View>: View {
    @Environment(\.seul) private var c
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(c.surface.color))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).stroke(c.line.color, lineWidth: 1))
    }
}

// MARK: - 다이얼로그

struct DialogConfig: Identifiable {
    let id = UUID()
    var title: String
    var message: String?
    var confirmTitle: String = "확인"
    var cancelTitle: String? = "취소"
    var destructive = false
    var onConfirm: () -> Void
    var onCancel: (() -> Void)?
}

/// 앱 공용 확인 다이얼로그(코너 반경 large). 바깥 탭으로 닫히지 않는다.
struct DialogOverlay: View {
    @Environment(\.seul) private var c
    let config: DialogConfig
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text(config.title)
                    .font(SeulFont.title(21))
                    .foregroundColor(c.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let m = config.message {
                    Text(m)
                        .font(SeulFont.body(15))
                        .foregroundColor(c.inkSoft.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    if let cancel = config.cancelTitle {
                        SecondaryButton(title: cancel) {
                            dismiss()
                            config.onCancel?()
                        }
                    }
                    PrimaryButton(title: config.confirmTitle,
                                  tint: config.destructive ? HSB(h: 0.0, s: 0.62, b: 0.78) : nil) {
                        dismiss()
                        config.onConfirm()
                    }
                }
                .padding(.top, 6)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).fill(c.surface.color))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}

extension View {
    func seulDialog(_ config: Binding<DialogConfig?>) -> some View {
        overlay {
            if let cfg = config.wrappedValue {
                DialogOverlay(config: cfg) { config.wrappedValue = nil }
            }
        }
        .animation(.easeOut(duration: 0.18), value: config.wrappedValue?.id)
    }
}

// MARK: - 할 일 카드

struct TaskCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(c.toneGradient(c.swatch(for: task.id)))
                .frame(width: 6)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(SeulFont.medium(15))
                    .foregroundColor(task.isFinished ? c.inkFaint.color : c.ink.color)
                    .strikethrough(task.isFinished && task.type == .once, color: c.inkFaint.color)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    StarsView(value: task.importance, size: 9)
                    if task.type == .recurring {
                        PillTag(text: progressText)
                    }
                    if let app = LinkableApp.find(task.linkedApp) {
                        Image(systemName: app.symbol)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(c.inkSoft.color)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surface.color))
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(c.line.color, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    private var progressText: String {
        if let t = task.target { return "\(task.frequency.label) · \(task.count)/\(t)" }
        return "\(task.frequency.label) · 누적 \(task.count)회"
    }
}
