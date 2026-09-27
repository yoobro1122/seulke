import SwiftUI

/// 체크인 모달: 블록 종료 시각이 지나면 자동으로 뜬다. 바깥 탭/스와이프로는 닫히지 않고
/// "완료했어요"/"못했어요" 중 하나를 눌러야 닫힌다. 누르면 리액션 애니메이션이 끝나는 시점에 자동으로 닫힘.
struct CheckinOverlay: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    let block: ScheduleBlock
    let task: TaskItem

    @State private var memo = ""
    @State private var reaction: ReactionView.Kind?
    @FocusState private var memoFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.36).ignoresSafeArea()
                .onTapGesture { memoFocused = false }

            VStack(spacing: 18) {
                if let r = reaction {
                    ReactionView(kind: r) {
                        store.finishCheckinPresentation()
                    }
                    .frame(height: 230)
                } else {
                    question
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).fill(c.surface.color))
            .padding(.horizontal, 22)
            .animation(.easeInOut(duration: 0.2), value: reaction)
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(c.toneGradient(c.swatch(for: task.id)))
                    .frame(width: 6, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(SeulFont.medium(16))
                        .foregroundColor(c.ink.color)
                        .lineLimit(2)
                    Text("\(Day.monthDay(block.date)) \(Day.hhmm(block.startMinute))–\(Day.hhmm(block.endMinute))")
                        .font(SeulFont.mono(11))
                        .foregroundColor(c.inkSoft.color)
                }
                Spacer()
                if task.type == .recurring {
                    PillTag(text: task.target.map { "\(task.count)/\($0)" } ?? "누적 \(task.count)회")
                }
            }

            Text("완료하셨나요?")
                .font(SeulFont.title(26))
                .foregroundColor(c.ink.color)

            TextField("한 줄 메모 (선택)", text: $memo)
                .focused($memoFocused)
                .font(SeulFont.body(15))
                .foregroundColor(c.ink.color)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surfaceAlt.color))

            HStack(spacing: 10) {
                SecondaryButton(title: "못했어요") { answer(false) }
                PrimaryButton(title: "완료했어요") { answer(true) }
            }
        }
    }

    private func answer(_ completed: Bool) {
        memoFocused = false
        store.haptic(completed ? .success : .soft)
        store.answerCheckin(blockId: block.id, completed: completed, memo: memo)
        reaction = completed ? .success : .fail
    }
}

/// "N회 완료될 때까지 계속할까요?" — 시도 횟수가 먼저 목표에 닿았는데 완료가 부족할 때 정확히 한 번만 뜬다.
struct GoalPromptOverlay: View {
    @EnvironmentObject private var store: AppStore
    let task: TaskItem

    var body: some View {
        let target = task.target ?? 0
        DialogOverlay(config: DialogConfig(
            title: "\(target)회 완료될 때까지 계속할까요?",
            message: "‘\(task.title)’ \(target)번 시도 중 \(task.count)번 완료했어요. 아니요를 누르면 여기서 반복을 끝내요.",
            confirmTitle: "네",
            cancelTitle: "아니요",
            onConfirm: {
                store.haptic(.success)
                store.answerGoalPrompt(taskId: task.id, keepGoing: true)
            },
            onCancel: {
                store.haptic(.warning)
                store.answerGoalPrompt(taskId: task.id, keepGoing: false)
            }
        )) {}
    }
}
