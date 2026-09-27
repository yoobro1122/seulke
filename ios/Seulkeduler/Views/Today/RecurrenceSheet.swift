import SwiftUI

/// 반복 설정: 매일 / 매주[요일] / 매월[일자·N번째 요일·마지막 날].
/// 앱 전체에 규칙은 하나뿐이며, 확정 시점의 이 날 타임라인이 템플릿으로 저장된다.
struct RecurrenceSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    @Environment(\.dismiss) private var dismiss
    let dateKey: String

    @State private var selected: RecurringRule?
    @State private var dialog: DialogConfig?

    private var dayLabel: String { dateKey == Day.todayKey ? "오늘" : Day.monthDay(dateKey) }

    var body: some View {
        let options = RecurringRule.options(for: dateKey)
        let blockCount = store.blocks(on: dateKey).count

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("반복 설정")
                        .font(SeulFont.title(24))
                        .foregroundColor(c.ink.color)
                    Text("\(dayLabel) 일정(\(blockCount)개)을 템플릿으로 저장해서, 앞으로 처음 여는 날에 자동으로 채워요.")
                        .font(SeulFont.body(14))
                        .foregroundColor(c.inkSoft.color)
                }

                if let current = store.settings.recurringRule {
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(text: "현재 반복")
                                Text("\(current.phrase) 반복 중")
                                    .font(SeulFont.medium(15))
                                    .foregroundColor(c.ink.color)
                                if let a = store.settings.recurringAnchorDate {
                                    Text("\(Day.monthDay(a)) 일정 기준")
                                        .font(SeulFont.mono(11))
                                        .foregroundColor(c.inkSoft.color)
                                }
                            }
                            Spacer()
                            Chip(title: "해제") {
                                dialog = DialogConfig(title: "반복을 해제할까요?",
                                                      message: "이미 채워진 일정은 그대로 남아요.",
                                                      confirmTitle: "해제", destructive: true) {
                                    store.haptic(.warning)
                                    store.clearRecurringRule()
                                }
                            }
                        }
                    }
                    Text("새로 설정하면 이전 규칙은 완전히 덮어써져요.")
                        .font(SeulFont.mono(11))
                        .foregroundColor(c.inkFaint.color)
                }

                group("매일", options.filter { if case .daily = $0 { return true }; return false })
                group("매주", options.filter { if case .weekly = $0 { return true }; return false })
                group("매월", options.filter {
                    switch $0 {
                    case .monthlyDay, .monthlyLastDay, .monthlyNthWeekday: return true
                    default: return false
                    }
                })

                if let rule = selected {
                    Text("\(dayLabel) 일정을 \(rule.phrase) 반복합니다.")
                        .font(SeulFont.medium(15))
                        .foregroundColor(c.accent.color)
                        .padding(.top, 4)
                }
                if blockCount == 0 {
                    Text("이 날엔 일정이 없어서 빈 템플릿이 저장돼요.")
                        .font(SeulFont.body(13))
                        .foregroundColor(c.inkSoft.color)
                }

                PrimaryButton(title: "설정 완료") {
                    guard let rule = selected else { return }
                    dialog = DialogConfig(title: "반복 설정",
                                          message: "\(dayLabel) 일정을 \(rule.phrase) 반복합니다.",
                                          confirmTitle: "확인") {
                        store.haptic(.success)
                        store.setRecurringRule(rule, anchor: dateKey)
                        dismiss()
                    }
                }
                .opacity(selected == nil ? 0.4 : 1)
                .disabled(selected == nil)
            }
            .padding(22)
        }
        .background(c.bg.color.ignoresSafeArea())
        .seulDialog($dialog)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func group(_ title: String, _ rules: [RecurringRule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            ForEach(rules, id: \.self) { rule in
                Button { selected = rule } label: {
                    HStack {
                        Image(systemName: selected == rule ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(selected == rule ? c.accent.color : c.inkFaint.color)
                        Text(rule.phrase)
                            .font(SeulFont.medium(15))
                            .foregroundColor(c.ink.color)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surface.color))
                    .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(selected == rule ? c.accent.color : c.line.color, lineWidth: selected == rule ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
