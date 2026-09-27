#if DEBUG
import Foundation

/// 디버그 빌드 전용: `-seedDemo` 실행 인자로 시연/UI 테스트용 데이터를 채운다.
enum DemoData {
    static func make(now: Date = Date()) -> AppData {
        var d = AppData.seed()
        let personal = d.projects[0].id
        let study = Project(name: "공부")
        d.projects.append(study)

        let today = Day.key(now)
        let yesterday = Day.add(-1, to: today)
        let nowMin = Day.minuteOfDay(now)
        func q(_ m: Int) -> Int { min(max(m / 15 * 15, 0), 1380) }

        let workout = TaskItem(title: "아침 운동", projectId: personal, type: .recurring, frequency: .daily,
                               target: 10, count: 3, importance: 4)
        let words = TaskItem(title: "영어 단어 50개", projectId: study.id, type: .recurring, frequency: .daily,
                             target: 5, count: 2, importance: 5)
        let groceries = TaskItem(title: "장보기", projectId: personal, importance: 2)
        let paper = TaskItem(title: "논문 읽기", projectId: study.id, importance: 5, memo: "3장까지")
        d.tasks = [workout, words, groceries, paper]

        let logged = ScheduleBlock(taskId: workout.id, date: today, startMinute: 420, durationMinutes: 60, state: .logged)
        let missed = ScheduleBlock(taskId: workout.id, date: yesterday, startMinute: 420, durationMinutes: 60, state: .missed)
        d.blocks = [
            logged,
            ScheduleBlock(taskId: words.id, date: today, startMinute: q(nowMin - 60), durationMinutes: 45),
            ScheduleBlock(taskId: paper.id, date: today, startMinute: q(nowMin + 30), durationMinutes: 90),
            ScheduleBlock(taskId: groceries.id, date: today, startMinute: q(nowMin + 180), durationMinutes: 30),
            missed
        ]

        func review(_ t: TaskItem, _ ok: Bool, _ memo: String, _ occ: Int, block: UUID? = nil, date: String) -> CheckinReview {
            CheckinReview(taskId: t.id, blockId: block, date: date, completed: ok, memo: memo, occurrence: occ,
                          createdAt: now.addingTimeInterval(TimeInterval(-86_400 * (6 - occ))))
        }
        d.reviews = [
            review(workout, true, "상쾌했다", 1, date: yesterday),
            review(workout, false, "늦잠", 2, date: yesterday),
            review(workout, true, "", 3, date: yesterday),
            review(workout, false, "비 옴", 4, block: missed.id, date: yesterday),
            review(workout, true, "5km 완주", 5, block: logged.id, date: today),
            review(words, true, "", 1, date: yesterday),
            review(words, false, "", 2, date: yesterday),
            review(words, true, "", 3, date: yesterday)
        ]
        d.settings.openedDates = [today, yesterday]
        return d
    }
}
#endif
