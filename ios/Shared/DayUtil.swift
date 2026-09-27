import Foundation

/// 날짜 키("yyyy-MM-dd")와 분 단위 시각을 다루는 헬퍼.
/// 안드로이드 버전과 동일하게 날짜는 문자열 키로, 시각은 자정 기준 분(0~1440)으로 저장한다.
enum Day {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ko_KR")
        c.timeZone = .current
        return c
    }()

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    static func date(_ key: String) -> Date {
        if let d = keyFormatter.date(from: key) { return calendar.startOfDay(for: d) }
        return calendar.startOfDay(for: Date())
    }

    static var todayKey: String { key(Date()) }

    static func add(_ days: Int, to key: String) -> String {
        Self.key(calendar.date(byAdding: .day, value: days, to: date(key)) ?? date(key))
    }

    static func minuteOfDay(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func dateTime(_ key: String, minute: Int) -> Date {
        calendar.date(byAdding: .minute, value: minute, to: date(key)) ?? date(key)
    }

    /// 1=일 ... 7=토
    static func weekday(_ key: String) -> Int {
        calendar.component(.weekday, from: date(key))
    }

    static func dayOfMonth(_ key: String) -> Int {
        calendar.component(.day, from: date(key))
    }

    static func hhmm(_ minute: Int) -> String {
        let m = max(0, min(minute, 1440))
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func monthDay(_ key: String) -> String {
        let d = date(key)
        let c = calendar.dateComponents([.month, .day], from: d)
        return "\(c.month ?? 1)월 \(c.day ?? 1)일"
    }

    static func monthDayWeekday(_ key: String) -> String {
        "\(monthDay(key)) (\(weekdaySymbols[weekday(key) - 1]))"
    }
}
