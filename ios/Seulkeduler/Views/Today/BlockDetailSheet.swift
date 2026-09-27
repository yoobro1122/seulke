import SwiftUI

/// 블록 상세 모달. 리뷰가 있으면 "그날의 기록" 섹션을 보여준다.
struct BlockDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    @Environment(\.dismiss) private var dismiss
    let blockId: UUID

    @State private var editingTaskId: UUID?

    var body: some View {
        Group {
            if let b = store.block(blockId) {
                content(b)
            } else {
                Text("삭제된 일정이에요")
                    .font(SeulFont.body(15))
                    .foregroundColor(c.inkSoft.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(c.bg.color.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(item: Binding(get: { editingTaskId.map { SlotID(id: $0) } },
                                       set: { editingTaskId = $0?.id })) { ref in
            TaskFormView(mode: .edit(ref.id))
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
    }

    private func content(_ b: ScheduleBlock) -> some View {
        let task = store.task(b.taskId)
        let tone = c.swatch(for: b.taskId)
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(c.toneGradient(tone))
                        .frame(width: 8, height: 54)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task?.title ?? "삭제된 할 일")
                            .font(SeulFont.title(24))
                            .foregroundColor(c.ink.color)
                        Text("\(Day.monthDayWeekday(b.date)) · \(Day.hhmm(b.startMinute))–\(Day.hhmm(b.endMinute))")
                            .font(SeulFont.mono(12))
                            .foregroundColor(c.inkSoft.color)
                        HStack(spacing: 8) {
                            if let p = store.project(task?.projectId) { PillTag(text: p.name) }
                            PillTag(text: stateText(b), strong: b.state == .logged)
                            if let t = task { StarsView(value: t.importance, size: 10) }
                        }
                    }
                }

                if let r = store.review(for: b) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "그날의 기록")
                        Card {
                            ReviewRow(review: r, showDate: false)
                        }
                    }
                }

                if let t = task, t.type == .recurring {
                    ProgressSummaryView(task: t, reviews: store.reviews(for: t.id))
                }

                if let t = task, !t.memo.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "메모")
                        Text(t.memo).font(SeulFont.body(15)).foregroundColor(c.ink.color)
                    }
                }

                HStack(spacing: 10) {
                    if let app = LinkableApp.find(task?.linkedApp) {
                        Chip(title: "\(app.name) 열기", symbol: app.symbol) { app.open() }
                    }
                    if let link = task?.link, !link.isEmpty, let url = URL(string: link.hasPrefix("http") ? link : "https://\(link)") {
                        Chip(title: "링크 열기", symbol: "link") { UIApplication.shared.open(url) }
                    }
                }

                VStack(spacing: 10) {
                    if task != nil {
                        SecondaryButton(title: "할 일 수정") { editingTaskId = b.taskId }
                    }
                    SecondaryButton(title: "스케줄에서 삭제", destructive: true) {
                        store.haptic(.warning)
                        store.removeBlock(b.id)
                        dismiss()
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
    }

    private func stateText(_ b: ScheduleBlock) -> String {
        switch b.state {
        case .logged: return "완료"
        case .missed: return "못했어요"
        case .planned: return b.checkinPending ? "체크인 대기" : "예정"
        }
    }
}

struct SlotID: Identifiable {
    let id: UUID
}
