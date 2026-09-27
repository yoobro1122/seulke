import SwiftUI
import WidgetKit

/// 홈 화면 2x2 원형 다이얼 위젯: 상단 현재 시각, 가운데 오늘 일정 도넛, 하단 지금/다음 일정.
/// iOS 위젯은 새로고침 예산이 있어서, 타임라인을 한 번 만들 때 앞으로 2시간치 분 단위 엔트리를 미리 넣어둔다.
/// 앱에서 데이터/테마가 바뀌면 WidgetCenter.reloadAllTimelines()로 즉시 다시 그린다.
struct DialProvider: TimelineProvider {
    func placeholder(in context: Context) -> DialEntry {
        DialEntry(date: Date(), data: AppData.seed())
    }

    func getSnapshot(in context: Context, completion: @escaping (DialEntry) -> Void) {
        completion(DialEntry(date: Date(), data: SharedStore.load() ?? AppData.seed()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DialEntry>) -> Void) {
        let data = SharedStore.load() ?? AppData.seed()
        let now = Date()
        let startOfMinute = Day.calendar.date(bySetting: .second, value: 0, of: now) ?? now
        let base = startOfMinute > now ? startOfMinute.addingTimeInterval(-60) : startOfMinute
        let entries = (0..<120).map { i in
            DialEntry(date: base.addingTimeInterval(TimeInterval(i * 60)), data: data)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@main
struct SeulDialWidget: Widget {
    let kind = "SeulDialWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DialProvider()) { entry in
            SeulWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 다이얼")
        .description("오늘 일정을 24시간 다이얼로 보여줘요.")
        .supportedFamilies([.systemSmall])
    }
}
