import Foundation

// 안드로이드 버전 data 패키지(Room 엔티티)의 필드 구조를 그대로 옮긴 모델.
// 저장은 AppData 하나를 JSON 파일로 통째로 기록한다(백업/복원 포맷과 동일).

enum TaskType: String, Codable, CaseIterable {
    case once = "ONCE"
    case recurring = "RECURRING"
}

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "매일"
        case .weekly: return "매주"
        case .monthly: return "매월"
        }
    }
}

enum BlockState: String, Codable {
    case planned = "PLANNED"
    case logged = "LOGGED"
    case missed = "MISSED"
}

struct Project: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var createdAt = Date()
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var projectId: UUID?
    var type: TaskType = .once
    var frequency: Frequency = .daily
    /// RECURRING 목표 완료 횟수. nil이면 무제한.
    var target: Int?
    /// RECURRING 누적 완료 횟수.
    var count: Int = 0
    var done: Bool = false
    /// 중요도 1~5 (별 개수)
    var importance: Int = 3
    var memo: String = ""
    var link: String = ""
    /// 연결 앱 ID (iOS에서는 URL 스킴 기반 LinkableApp.id)
    var linkedApp: String?
    var recurringEnded: Bool = false
    var recurringGoalPromptAnswered: Bool = false
    var createdAt = Date()
    var completedAt: Date?

    var isFinished: Bool { type == .once ? done : recurringEnded }
}

struct ScheduleBlock: Codable, Identifiable, Hashable {
    var id = UUID()
    var taskId: UUID
    var date: String
    var startMinute: Int
    var durationMinutes: Int
    var checkinPending: Bool = false
    var state: BlockState = .planned

    var endMinute: Int { startMinute + durationMinutes }
}

struct CheckinReview: Codable, Identifiable, Hashable {
    var id = UUID()
    var taskId: UUID
    /// 참고용(블록이 지워져도 리뷰는 남는다)
    var blockId: UUID?
    var date: String
    var completed: Bool
    var memo: String
    /// 그 시점 반복 회차(몇 번째 시도였는지) 스냅샷
    var occurrence: Int
    var createdAt = Date()
}

enum TodayDefaultView: String, Codable {
    case list = "LIST"
    case dial = "DIAL"
}

struct TemplateItem: Codable, Hashable {
    var taskId: UUID
    var startMinute: Int
    var durationMinutes: Int
}

struct AppSettings: Codable {
    var todayDefaultView: TodayDefaultView = .list
    /// 1 = 일요일, 2 = 월요일
    var weekStart: Int = 1
    var notificationsEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// "mono" 또는 CustomColorTheme.id.uuidString
    var colorTheme: String = ThemeIds.mono
    var recurringRule: RecurringRule?
    var recurringTemplate: [TemplateItem] = []
    var recurringAnchorDate: String?
    /// 한 번이라도 열어본 날짜들. 반복 템플릿 자동 채움은 여기에 없는 오늘/미래 날짜에만 적용된다.
    var openedDates: Set<String> = []
}

struct CustomColorTheme: Codable, Identifiable, Hashable {
    var id = UUID()
    var baseHue: Double
    /// 채도 배율(내장 '타이탄'처럼 차분한 테마용). 커스텀 생성 시 기본 1.
    var saturation: Double = 1
    /// 스와치 7칸별 개별 hue 오버라이드(nil이면 기본 유도값)
    var presetHueOverrides: [Double?] = Array(repeating: nil, count: 7)
}

enum ThemeIds {
    static let mono = "mono"
}

struct AppData: Codable {
    var schemaVersion: Int = 1
    var projects: [Project] = []
    var tasks: [TaskItem] = []
    var blocks: [ScheduleBlock] = []
    var reviews: [CheckinReview] = []
    var settings = AppSettings()
    var customThemes: [CustomColorTheme] = []

    static func seed() -> AppData {
        var d = AppData()
        d.projects = [Project(name: "개인")]
        d.customThemes = ThemeCatalog.seedThemes()
        return d
    }
}

// MARK: - 반복 규칙 (앱 전체에 단 하나)

enum RecurringRule: Codable, Hashable {
    case daily
    case weekly(weekday: Int)
    case monthlyDay(day: Int)
    case monthlyLastDay
    case monthlyNthWeekday(nth: Int, weekday: Int)

    static let ordinals = ["첫째", "둘째", "셋째", "넷째", "다섯째"]

    var phrase: String {
        switch self {
        case .daily:
            return "매일"
        case .weekly(let w):
            return "매주 \(Day.weekdaySymbols[w - 1])요일"
        case .monthlyDay(let day):
            return "매월 \(day)일"
        case .monthlyLastDay:
            return "매월 마지막 날"
        case .monthlyNthWeekday(let nth, let w):
            return "매월 \(Self.ordinals[max(0, min(nth - 1, 4))]) 주 \(Day.weekdaySymbols[w - 1])요일"
        }
    }

    func matches(_ key: String) -> Bool {
        let d = Day.date(key)
        let cal = Day.calendar
        let comps = cal.dateComponents([.day, .weekday], from: d)
        let day = comps.day ?? 1
        let weekday = comps.weekday ?? 1
        switch self {
        case .daily:
            return true
        case .weekly(let w):
            return weekday == w
        case .monthlyDay(let target):
            return day == target
        case .monthlyLastDay:
            return (cal.range(of: .day, in: .month, for: d)?.count ?? 31) == day
        case .monthlyNthWeekday(let nth, let w):
            return weekday == w && (day - 1) / 7 + 1 == nth
        }
    }

    static func options(for key: String) -> [RecurringRule] {
        let wd = Day.weekday(key)
        let day = Day.dayOfMonth(key)
        return [.daily, .weekly(weekday: wd), .monthlyDay(day: day),
                .monthlyNthWeekday(nth: (day - 1) / 7 + 1, weekday: wd), .monthlyLastDay]
    }
}

// MARK: - 조회 헬퍼 (앱/위젯 공용)

extension AppData {
    func task(_ id: UUID) -> TaskItem? { tasks.first { $0.id == id } }

    func storedBlocks(on key: String) -> [ScheduleBlock] {
        blocks.filter { $0.date == key }.sorted { $0.startMinute < $1.startMinute }
    }

    /// 아직 열어본 적 없는 오늘/미래 날짜라면 반복 템플릿에서 채워질 블록들.
    func templateBlocks(on key: String, todayKey: String = Day.todayKey) -> [ScheduleBlock] {
        guard !settings.openedDates.contains(key),
              key >= todayKey,
              let rule = settings.recurringRule,
              let anchor = settings.recurringAnchorDate,
              key > anchor,
              rule.matches(key) else { return [] }
        let stored = storedBlocks(on: key)
        return settings.recurringTemplate.compactMap { item in
            guard let t = task(item.taskId), !t.isFinished else { return nil }
            let end = item.startMinute + item.durationMinutes
            let overlaps = stored.contains { $0.startMinute < end && $0.endMinute > item.startMinute }
            if overlaps { return nil }
            return ScheduleBlock(taskId: item.taskId, date: key,
                                 startMinute: item.startMinute, durationMinutes: item.durationMinutes)
        }
    }

    /// 저장된 블록 + (미개봉 날짜라면) 템플릿 블록.
    func effectiveBlocks(on key: String, todayKey: String = Day.todayKey) -> [ScheduleBlock] {
        (storedBlocks(on: key) + templateBlocks(on: key, todayKey: todayKey))
            .sorted { $0.startMinute < $1.startMinute }
    }
}
