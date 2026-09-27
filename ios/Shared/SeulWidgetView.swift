import SwiftUI
import WidgetKit

/// 위젯 화면(앱 테스트에서도 렌더링해 확인할 수 있도록 공용 폴더에 둔다)
struct DialEntry: TimelineEntry {
    let date: Date
    let data: AppData
}

struct SeulWidgetView: View {
    let entry: DialEntry

    var body: some View {
        let p = ThemeCatalog.palette(themeId: entry.data.settings.colorTheme, customs: entry.data.customThemes)
        let key = Day.key(entry.date)
        let nowMin = Day.minuteOfDay(entry.date)
        let blocks = entry.data.effectiveBlocks(on: key, todayKey: key)
        let current = blocks.first { $0.startMinute <= nowMin && nowMin < $0.endMinute }
        let next = blocks.first { $0.startMinute > nowMin }

        VStack(spacing: 4) {
            Text(Day.hhmm(nowMin))
                .font(SeulFont.monoMedium(13))
                .foregroundColor(p.ink.color)
            SeulDial(items: entry.data.dialItems(on: key, palette: p, now: entry.date),
                     palette: p, now: entry.date, ringWidth: 13, showCenter: false, showLabels: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer(current: current, next: next, palette: p)
        }
        .widgetBackground(p.bg.color)
        .widgetURL(URL(string: "seulkeduler://today"))
    }

    @ViewBuilder
    private func footer(current: ScheduleBlock?, next: ScheduleBlock?, palette p: SeulPalette) -> some View {
        if let b = current {
            label(prefix: "지금", title: entry.data.task(b.taskId)?.title ?? "", color: p.swatch(for: b.taskId), p)
        } else if let b = next {
            label(prefix: Day.hhmm(b.startMinute), title: entry.data.task(b.taskId)?.title ?? "", color: p.swatch(for: b.taskId), p)
        } else {
            Text("남은 일정 없음")
                .font(SeulFont.body(11))
                .foregroundColor(p.inkSoft.color)
                .lineLimit(1)
        }
    }

    private func label(prefix: String, title: String, color: HSB, _ p: SeulPalette) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color.color).frame(width: 6, height: 6)
            Text(prefix).font(SeulFont.mono(10)).foregroundColor(p.accent.color)
            Text(title).font(SeulFont.medium(11)).foregroundColor(p.ink.color)
        }
        .lineLimit(1)
    }
}


extension View {
    /// iOS 17+는 containerBackground로 배경을 지정해야 위젯이 그려진다("Please adopt containerBackground API").
    /// 이 API는 Xcode 15(Swift 5.9) SDK부터 있으므로 컴파일러 버전으로 분기한다.
    /// iOS 17+에서는 시스템이 여백을 넣어 주므로 직접 넣는 여백은 iOS 16 이하에서만 쓴다.
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        #if swift(>=5.9)
        if #available(iOS 17.0, *) {
            self.frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(color, for: .widget)
        } else {
            legacyWidgetBackground(color)
        }
        #else
        legacyWidgetBackground(color)
        #endif
    }

    private func legacyWidgetBackground(_ color: Color) -> some View {
        self.padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
    }
}
