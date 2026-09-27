import SwiftUI

/// 빈 시간대 길게 누르기 → "이벤트 선택" 모달.
/// 프로젝트별 미완료 할 일 중 골라 즉시 배치, 맨 위 "+ 새 이벤트 추가"로 전체 폼을 열 수도 있다.
struct EventPickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    @Environment(\.dismiss) private var dismiss
    let dateKey: String
    let minute: Int

    @State private var showForm = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("이벤트 선택")
                    .font(SeulFont.title(22))
                    .foregroundColor(c.ink.color)
                Text("\(Day.monthDayWeekday(dateKey)) \(Day.hhmm(minute))부터 30분")
                    .font(SeulFont.mono(12))
                    .foregroundColor(c.inkSoft.color)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    Button { showForm = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("새 이벤트 추가").font(SeulFont.medium(15))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.accentGradient))
                    }
                    .buttonStyle(PressableStyle())

                    if let e = errorText {
                        Text(e)
                            .font(SeulFont.body(13))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.top, 4)
                    }

                    ForEach(store.activeTaskGroups.filter { !$0.tasks.isEmpty }, id: \.project?.id) { group in
                        SectionLabel(text: group.project?.name ?? "미분류").padding(.top, 12)
                        ForEach(group.tasks) { t in
                            Button { place(t.id) } label: { TaskCard(task: t) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(c.bg.color.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showForm) {
            TaskFormView(mode: .new(projectId: nil)) { saved in
                // 전체 화면 폼이 내려간 뒤에 배치하고 시트를 닫는다
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { place(saved.id) }
            }
            .environmentObject(store)
            .environment(\.seul, store.palette)
        }
    }

    private func place(_ taskId: UUID) {
        if store.placeBlock(taskId: taskId, date: dateKey, start: minute) {
            dismiss()
        } else {
            errorText = "이 시간엔 이미 다른 일정이 있어요."
        }
    }
}
