import SwiftUI

/// 달력 뷰: 월 단위 이동, 요일 헤더는 '주 시작 요일' 설정을 따름, 스케줄 있는 날엔 점, 날짜 탭 → 목록 뷰.
struct CalendarModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var today: TodayState
    @Environment(\.seul) private var c
    let bottomInset: CGFloat

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let cal = Day.calendar
        let month = today.calendarMonth
        let comps = cal.dateComponents([.year, .month], from: month)
        let first = cal.date(from: comps) ?? month
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let weekStart = store.settings.weekStart
        let leading = (cal.component(.weekday, from: first) - weekStart + 7) % 7
        let symbols = (0..<7).map { Day.weekdaySymbols[(weekStart - 1 + $0) % 7] }
        let todayKey = Day.todayKey

        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    IconButton(symbol: "chevron.left", label: "이전 달") { shiftMonth(-1) }
                    Spacer()
                    Text(verbatim: "\(comps.year ?? 2026)년 \(comps.month ?? 1)월")
                        .font(SeulFont.title(22))
                        .foregroundColor(c.ink.color)
                    Spacer()
                    IconButton(symbol: "chevron.right", label: "다음 달") { shiftMonth(1) }
                }

                // 요일 헤더/빈 칸/날짜 칸이 한 그리드에 섞이므로 ID가 겹치지 않게 하나의 셀 목록으로 만든다
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(cells(symbols: symbols, leading: leading, days: daysInMonth)) { cell in
                        switch cell.kind {
                        case .header(let symbol):
                            Text(symbol)
                                .font(SeulFont.mono(11))
                                .foregroundColor(symbol == "일" ? Color.red.opacity(0.65) : c.inkSoft.color)
                                .frame(height: 28)
                        case .blank:
                            Color.clear.frame(height: 52)
                        case .day(let day):
                            let date = cal.date(byAdding: .day, value: day - 1, to: first) ?? first
                            dayCell(day: day, key: Day.key(date), todayKey: todayKey)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(c.surface.color))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, bottomInset + 20)
        }
    }

    private func dayCell(day: Int, key: String, todayKey: String) -> some View {
        let selected = key == today.dateKey
        let isToday = key == todayKey
        let hasSchedule = store.hasSchedule(on: key)
        return Button {
            today.dateKey = key
            today.mode = .list
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(isToday ? SeulFont.monoMedium(15) : SeulFont.mono(15))
                    .foregroundColor(selected ? .white : (isToday ? c.accent.color : c.ink.color))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(selected ? AnyShapeStyle(c.accentGradient) : AnyShapeStyle(Color.clear))
                            .overlay(Circle().stroke(isToday && !selected ? c.accent.color : Color.clear, lineWidth: 1.2))
                    )
                Circle()
                    .fill(hasSchedule ? c.accent.color : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private struct Cell: Identifiable {
        enum Kind {
            case header(String)
            case blank
            case day(Int)
        }
        let id: String
        let kind: Kind
    }

    private func cells(symbols: [String], leading: Int, days: Int) -> [Cell] {
        symbols.enumerated().map { Cell(id: "h\($0.offset)", kind: .header($0.element)) }
            + (0..<leading).map { Cell(id: "b\($0)", kind: .blank) }
            + (1...days).map { Cell(id: "d\($0)", kind: .day($0)) }
    }

    private func shiftMonth(_ delta: Int) {
        today.calendarMonth = Day.calendar.date(byAdding: .month, value: delta, to: today.calendarMonth) ?? today.calendarMonth
    }
}
