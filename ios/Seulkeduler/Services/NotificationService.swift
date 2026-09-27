import Foundation
import UserNotifications

/// 일정 시작 로컬 알림. 안드로이드의 AlarmManager+BootReceiver 역할을 UNUserNotificationCenter가 대신한다.
/// 데이터가 바뀔 때마다 앞으로 14일치 예약을 통째로 다시 건다(iOS 대기 알림 한도 64개 → 60개로 제한).
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var pending: DispatchWorkItem?
    private let idPrefix = "seul.block."

    /// 중요도별 알림 시점(시작 몇 분 전). 1~2개는 알림 없음.
    static let offsetsByImportance: [Int: [Int]] = [
        1: [], 2: [], 3: [0], 4: [10, 0], 5: [30, 10, 0]
    ]

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { s in
            DispatchQueue.main.async { completion(s.authorizationStatus) }
        }
    }

    func scheduleRefresh(_ data: AppData) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reschedule(data) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func reschedule(_ data: AppData) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
            guard data.settings.notificationsEnabled else { return }

            let now = Date()
            let todayKey = Day.key(now)
            let lastKey = Day.add(14, to: todayKey)
            var items: [(Date, UNNotificationRequest)] = []

            for b in data.blocks where b.state == .planned && b.date >= todayKey && b.date <= lastKey {
                guard let task = data.task(b.taskId), !task.isFinished else { continue }
                let start = Day.dateTime(b.date, minute: b.startMinute)
                for offset in Self.offsetsByImportance[task.importance] ?? [] {
                    let fire = start.addingTimeInterval(TimeInterval(-offset * 60))
                    guard fire > now else { continue }
                    let msg = Self.message(importance: task.importance, minutesBefore: offset, title: task.title)
                    let content = UNMutableNotificationContent()
                    content.title = msg.title
                    content.body = msg.body
                    content.sound = .default
                    let comps = Day.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let req = UNNotificationRequest(identifier: "\(self.idPrefix)\(b.id.uuidString).\(offset)",
                                                    content: content, trigger: trigger)
                    items.append((fire, req))
                }
            }
            for (_, req) in items.sorted(by: { $0.0 < $1.0 }).prefix(60) {
                self.center.add(req)
            }
        }
    }

    /// 중요도 5단계별 메시지 톤
    static func message(importance: Int, minutesBefore: Int, title: String) -> (title: String, body: String) {
        switch importance {
        case 5:
            switch minutesBefore {
            case 30: return ("30분 뒤 시작", "‘\(title)’ 준비를 시작해볼까요? 가장 중요한 일정이에요.")
            case 10: return ("10분 뒤 시작", "‘\(title)’ 곧 시작해요. 꼭 챙겨야 하는 일정이에요!")
            default: return ("지금 시작!", "‘\(title)’ 지금 시작할 시간이에요. 오늘의 핵심 일정이에요.")
            }
        case 4:
            if minutesBefore == 10 { return ("10분 뒤 시작", "곧 ‘\(title)’ 시작해요. 슬슬 준비해요.") }
            return ("일정 시작", "‘\(title)’ 시작할 시간이에요. 힘내요!")
        case 3:
            return ("일정 시작", "‘\(title)’ 시작할 시간이에요.")
        case 2:
            return ("가벼운 일정", "‘\(title)’ 여유 있을 때 해봐요.")
        default:
            return ("느긋한 일정", "‘\(title)’ 생각나면 해도 괜찮아요.")
        }
    }
}
