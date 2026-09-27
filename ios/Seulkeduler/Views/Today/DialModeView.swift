import SwiftUI

/// 원형(다이얼) 뷰: 24시간 도넛형 두꺼운 호. 읽기 전용(드래그/추가 없음).
struct DialModeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    let dateKey: String
    let bottomInset: CGFloat
    var onTapBlock: (ScheduleBlock) -> Void

    @State private var now = Date()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let isToday = dateKey == Day.key(now)
        let blocks = store.blocks(on: dateKey)

        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                SeulDial(items: store.data.dialItems(on: dateKey, palette: c, now: now),
                         palette: c, now: isToday ? now : nil, ringWidth: 38)
                    .frame(maxWidth: 330)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                if blocks.isEmpty {
                    Text("이 날은 아직 일정이 없어요")
                        .font(SeulFont.body(14))
                        .foregroundColor(c.inkSoft.color)
                } else {
                    VStack(spacing: 8) {
                        ForEach(blocks) { b in
                            Button { onTapBlock(b) } label: { row(b) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, bottomInset + 20)
        }
        .onReceive(clock) { now = $0 }
    }

    private func row(_ b: ScheduleBlock) -> some View {
        HStack(spacing: 12) {
            Circle().fill(c.toneGradient(c.swatch(for: b.taskId))).frame(width: 12, height: 12)
            Text("\(Day.hhmm(b.startMinute))–\(Day.hhmm(b.endMinute))")
                .font(SeulFont.mono(12))
                .foregroundColor(c.inkSoft.color)
            Text(store.task(b.taskId)?.title ?? "삭제된 할 일")
                .font(SeulFont.medium(14))
                .foregroundColor(c.ink.color)
                .lineLimit(1)
            Spacer()
            if b.state == .logged {
                Image(systemName: "checkmark.circle.fill").foregroundColor(c.accent.color)
            } else if b.state == .missed {
                Image(systemName: "minus.circle").foregroundColor(c.inkFaint.color)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surface.color))
    }
}
