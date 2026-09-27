import SwiftUI

struct SlotRef: Identifiable {
    let minute: Int
    var id: Int { minute }
}

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var today: TodayState
    @Environment(\.seul) private var c
    let bottomInset: CGFloat

    @State private var pickerSlot: SlotRef?
    @State private var detailBlock: ScheduleBlock?
    @State private var showRecurrence = false

    private var isToday: Bool { today.dateKey == Day.todayKey }

    var body: some View {
        VStack(spacing: 0) {
            header
            modeContent
        }
        .onAppear { store.openDay(today.dateKey) }
        .onChange(of: today.dateKey) { store.openDay($0) }
        .sheet(item: $pickerSlot) { slot in
            EventPickerSheet(dateKey: today.dateKey, minute: slot.minute)
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
        .sheet(item: $detailBlock) { b in
            BlockDetailSheet(blockId: b.id)
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
        .sheet(isPresented: $showRecurrence) {
            RecurrenceSheet(dateKey: today.dateKey)
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch today.mode {
        case .list:
            TimelineListView(dateKey: today.dateKey, bottomInset: bottomInset,
                             onLongPressSlot: { pickerSlot = SlotRef(minute: $0) },
                             onTapBlock: { detailBlock = $0 })
        case .dial:
            DialModeView(dateKey: today.dateKey, bottomInset: bottomInset, onTapBlock: { detailBlock = $0 })
        case .calendar:
            CalendarModeView(bottomInset: bottomInset)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                IconButton(symbol: "chevron.left", label: "이전 날") { today.dateKey = Day.add(-1, to: today.dateKey) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(subtitle)
                        .font(SeulFont.mono(11))
                        .foregroundColor(isToday ? c.accent.color : c.inkSoft.color)
                    Text(Day.monthDay(today.dateKey))
                        .font(SeulFont.title(26))
                        .foregroundColor(c.ink.color)
                }
                .frame(minWidth: 110, alignment: .leading)
                IconButton(symbol: "chevron.right", label: "다음 날") { today.dateKey = Day.add(1, to: today.dateKey) }
                Spacer()
                if !isToday {
                    Chip(title: "오늘") {
                        today.dateKey = Day.todayKey
                        today.calendarMonth = Date()
                    }
                }
                IconButton(symbol: store.settings.recurringRule == nil ? "repeat" : "repeat.circle.fill", label: "반복 설정") {
                    showRecurrence = true
                }
            }
            ModeSwitcher()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var subtitle: String {
        let wd = Day.weekdaySymbols[Day.weekday(today.dateKey) - 1]
        let year = today.dateKey.prefix(4)
        return isToday ? "\(year) · \(wd)요일 · 오늘" : "\(year) · \(wd)요일"
    }
}

struct ModeSwitcher: View {
    @EnvironmentObject private var today: TodayState
    @Environment(\.seul) private var c

    var body: some View {
        HStack(spacing: 4) {
            item(.list, "list.bullet", "목록")
            item(.dial, "clock", "원형")
            item(.calendar, "calendar", "달력")
        }
        .padding(4)
        .background(Capsule().fill(c.surfaceAlt.color))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: today.mode)
    }

    private func item(_ mode: TodayState.Mode, _ symbol: String, _ title: String) -> some View {
        let active = today.mode == mode
        return Button {
            if mode == .calendar { today.calendarMonth = Day.date(today.dateKey) }
            today.mode = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(title).font(SeulFont.medium(13))
            }
            .foregroundColor(active ? c.ink.color : c.inkSoft.color)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Capsule().fill(active ? c.surface.color : Color.clear)
                .shadow(color: .black.opacity(active ? 0.06 : 0), radius: 4, y: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
