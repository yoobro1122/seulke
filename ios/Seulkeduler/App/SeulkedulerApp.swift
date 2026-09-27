import SwiftUI

@main
struct SeulkedulerApp: App {
    @StateObject private var store: AppStore
    @StateObject private var today: TodayState

    init() {
        let s = AppStore()
        _store = StateObject(wrappedValue: s)
        // 설정의 '오늘 탭 기본 화면'은 앱 시작 시 딱 한 번만 반영
        _today = StateObject(wrappedValue: TodayState(mode: s.settings.todayDefaultView == .dial ? .dial : .list))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(today)
                .environment(\.seul, store.palette)
                .preferredColorScheme(.light)
        }
    }
}

/// 오늘 탭 화면 상태(선택 날짜, 뷰 모드, 바텀시트 단계)
final class TodayState: ObservableObject {
    enum Mode: String, CaseIterable {
        case list, dial, calendar
    }

    enum SheetDetent {
        case peek, half, full
    }

    @Published var mode: Mode
    @Published var dateKey: String = Day.todayKey
    @Published var sheet: SheetDetent = .peek
    @Published var calendarMonth: Date = Date()
    /// 바텀시트에서 타임라인으로 끌고 있는 할 일
    @Published var draggingTaskId: UUID?

    init(mode: Mode) {
        self.mode = mode
    }
}
