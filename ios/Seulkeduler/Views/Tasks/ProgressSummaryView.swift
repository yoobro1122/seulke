import SwiftUI

/// 진행 현황 요약(RECURRING 전용) 가로 바.
/// - 목표가 있고 목표+미완료 ≤ 12: 시도 순서대로 채운 세그먼트 칸 + 목표까지 남은 칸은 점선
/// - 그 외(12 초과/무제한): 완료:미완료:남음 비율의 연속형 바
/// 완료=accent, 미완료=inkFaint, 남음=점선 아웃라인(전부 테마 유도색)
struct ProgressSummaryView: View {
    @Environment(\.seul) private var c
    let task: TaskItem
    let reviews: [CheckinReview]

    var body: some View {
        let attempts = reviews.sorted { $0.createdAt < $1.createdAt }.map(\.completed)
        let completed = attempts.filter { $0 }.count
        let missed = attempts.count - completed

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "진행 현황")
                Spacer()
                if let target = task.target {
                    PillTag(text: "\(task.count)/\(target) 완료", strong: true)
                } else {
                    PillTag(text: "누적 \(task.count)회", strong: true)
                }
            }
            if let target = task.target, target + missed <= 12 {
                segmented(attempts: attempts, remaining: max(0, target - completed))
            } else {
                continuous(completed: completed, missed: missed,
                           remaining: task.target.map { max(0, $0 - completed) } ?? 0)
            }
        }
    }

    private func segmented(attempts: [Bool], remaining: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(attempts.enumerated()), id: \.offset) { _, ok in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(ok ? c.accent.color : c.inkFaint.color.opacity(0.55))
            }
            ForEach(0..<remaining, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(c.inkFaint.color, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
        }
        .frame(height: 18)
    }

    private func continuous(completed: Int, missed: Int, remaining: Int) -> some View {
        let total = max(1, completed + missed + remaining)
        return GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 3) {
                if completed > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(c.accent.color)
                        .frame(width: w * CGFloat(completed) / CGFloat(total))
                }
                if missed > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(c.inkFaint.color.opacity(0.55))
                        .frame(width: w * CGFloat(missed) / CGFloat(total))
                }
                if remaining > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(c.inkFaint.color, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                }
                if completed + missed + remaining == 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(c.inkFaint.color, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                }
            }
        }
        .frame(height: 18)
    }
}
