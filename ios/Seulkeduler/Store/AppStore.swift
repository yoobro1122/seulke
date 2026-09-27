import SwiftUI
import WidgetKit

/// 앱 전체 상태(ViewModel). 모든 변경은 mutate를 거쳐 JSON 저장 + 위젯 갱신 + 알림 재예약까지 이어진다.
@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    /// 현재 떠 있는 체크인 모달의 블록
    @Published var presentedCheckinId: UUID?
    /// "N회 완료될 때까지 계속할까요?" 모달 대상
    @Published var goalPromptTaskId: UUID?
    /// 루트에서 띄우는 공용 다이얼로그
    @Published var dialog: DialogConfig?

    /// 테스트용 인메모리 스토어는 디스크/위젯/알림을 건드리지 않는다.
    private var persistsToDisk = true

    init(inMemory data: AppData) {
        self.data = data
        persistsToDisk = false
    }

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedDemo") || args.contains("-seedEmpty") {
            data = args.contains("-seedDemo") ? DemoData.make() : AppData.seed()
            SharedStore.save(data)
            return
        }
        #endif
        if let loaded = SharedStore.load() {
            data = loaded
        } else {
            data = AppData.seed()
            SharedStore.save(data)
        }
    }

    // MARK: - 공통

    var settings: AppSettings { data.settings }

    var palette: SeulPalette {
        ThemeCatalog.palette(themeId: data.settings.colorTheme, customs: data.customThemes)
    }

    private func mutate(_ body: (inout AppData) -> Void) {
        body(&data)
        persist()
    }

    private func persist() {
        guard persistsToDisk else { return }
        SharedStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationService.shared.scheduleRefresh(data)
    }

    func haptic(_ kind: Haptics.Kind) {
        Haptics.play(kind, enabled: data.settings.hapticsEnabled)
    }

    // MARK: - 조회

    func task(_ id: UUID) -> TaskItem? { data.task(id) }
    func project(_ id: UUID?) -> Project? { id.flatMap { pid in data.projects.first { $0.id == pid } } }

    var sortedProjects: [Project] { data.projects.sorted { $0.createdAt < $1.createdAt } }

    var activeTasks: [TaskItem] { data.tasks.filter { !$0.isFinished } }

    var finishedTasks: [TaskItem] {
        data.tasks.filter { $0.isFinished }.sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    func activeTasks(in projectId: UUID?) -> [TaskItem] {
        activeTasks.filter { $0.projectId == projectId }
            .sorted { $0.importance != $1.importance ? $0.importance > $1.importance : $0.createdAt < $1.createdAt }
    }

    /// 프로젝트별 미완료 할 일 묶음(프로젝트 없는 할 일은 마지막 '미분류').
    var activeTaskGroups: [(project: Project?, tasks: [TaskItem])] {
        var groups: [(Project?, [TaskItem])] = sortedProjects.map { ($0, activeTasks(in: $0.id)) }
        let loose = activeTasks.filter { t in t.projectId == nil || project(t.projectId) == nil }
        if !loose.isEmpty { groups.append((nil, loose)) }
        return groups.map { (project: $0.0, tasks: $0.1) }
    }

    func blocks(on key: String) -> [ScheduleBlock] { data.storedBlocks(on: key) }

    func block(_ id: UUID) -> ScheduleBlock? { data.blocks.first { $0.id == id } }

    func reviews(for taskId: UUID) -> [CheckinReview] {
        data.reviews.filter { $0.taskId == taskId }.sorted { $0.createdAt > $1.createdAt }
    }

    func review(for block: ScheduleBlock) -> CheckinReview? {
        data.reviews.first { $0.blockId == block.id }
            ?? data.reviews.first { $0.taskId == block.taskId && $0.date == block.date && $0.blockId == nil }
    }

    func hasSchedule(on key: String) -> Bool {
        data.blocks.contains { $0.date == key } || !data.templateBlocks(on: key).isEmpty
    }

    // MARK: - 날짜 열기(반복 템플릿 자동 채움)

    func openDay(_ key: String) {
        guard !data.settings.openedDates.contains(key) else { return }
        mutate { d in
            let fill = d.templateBlocks(on: key)
            d.blocks.append(contentsOf: fill)
            d.settings.openedDates.insert(key)
        }
    }

    // MARK: - 스케줄 블록

    /// 빈 슬롯에 블록 생성. 다른 할 일과 겹치면 다음 블록 시작까지로 줄이고, 들어갈 자리가 없으면 false.
    @discardableResult
    func placeBlock(taskId: UUID, date: String, start: Int, duration: Int = 30) -> Bool {
        let s = min(max(TimelineMath.snap(Double(start)), 0), TimelineMath.dayMinutes - TimelineMath.minDuration)
        var e = min(s + duration, TimelineMath.dayMinutes)
        let others = data.blocks.filter { $0.date == date && $0.taskId != taskId }
        if others.contains(where: { $0.startMinute <= s && s < $0.endMinute }) { return false }
        if let next = others.filter({ $0.startMinute >= s }).map(\.startMinute).min(), next < e { e = next }
        guard e - s >= TimelineMath.minDuration else { return false }
        mutate { d in
            d.blocks.append(ScheduleBlock(taskId: taskId, date: date, startMinute: s, durationMinutes: e - s))
            d.settings.openedDates.insert(date)
            Self.mergeAdjacent(&d, date: date, taskId: taskId)
        }
        return true
    }

    /// 이동/리사이즈 확정. 다른 할 일 블록과 겹치면 거부(원위치).
    @discardableResult
    func updateBlock(_ id: UUID, start: Int, duration: Int) -> Bool {
        guard let b = block(id) else { return false }
        let end = start + duration
        let clash = data.blocks.contains {
            $0.id != id && $0.date == b.date && $0.taskId != b.taskId && $0.startMinute < end && $0.endMinute > start
        }
        if clash { return false }
        mutate { d in
            guard let i = d.blocks.firstIndex(where: { $0.id == id }) else { return }
            d.blocks[i].startMinute = start
            d.blocks[i].durationMinutes = duration
            Self.mergeAdjacent(&d, date: b.date, taskId: b.taskId)
        }
        return true
    }

    /// 스케줄에서만 삭제(할 일은 유지)
    func removeBlock(_ id: UUID) {
        mutate { d in d.blocks.removeAll { $0.id == id } }
        if presentedCheckinId == id { presentedCheckinId = nil }
    }

    /// 같은 날, 같은 할 일의 예정 블록끼리 맞닿거나 겹치면 하나로 합친다.
    static func mergeAdjacent(_ d: inout AppData, date: String, taskId: UUID) {
        let candidates = d.blocks
            .filter { $0.date == date && $0.taskId == taskId && $0.state == .planned && !$0.checkinPending }
            .sorted { $0.startMinute < $1.startMinute }
        guard candidates.count > 1 else { return }
        var merged: [ScheduleBlock] = []
        for b in candidates {
            if var last = merged.last, b.startMinute <= last.endMinute {
                last.durationMinutes = max(last.endMinute, b.endMinute) - last.startMinute
                merged[merged.count - 1] = last
            } else {
                merged.append(b)
            }
        }
        let ids = Set(candidates.map(\.id))
        d.blocks.removeAll { ids.contains($0.id) }
        d.blocks.append(contentsOf: merged)
    }

    /// 종료된 할 일의 오늘 남은/미래 예정 블록 정리(미리 채워진 반복 블록 포함)
    static func removeFutureBlocks(_ d: inout AppData, taskId: UUID, now: Date = Date()) {
        let today = Day.key(now)
        let nowMin = Day.minuteOfDay(now)
        d.blocks.removeAll { b in
            guard b.taskId == taskId, b.state == .planned, !b.checkinPending else { return false }
            return b.date > today || (b.date == today && b.startMinute >= nowMin)
        }
    }

    // MARK: - 반복 설정

    func setRecurringRule(_ rule: RecurringRule, anchor: String) {
        mutate { d in
            d.settings.recurringRule = rule
            d.settings.recurringAnchorDate = anchor
            d.settings.recurringTemplate = d.blocks
                .filter { $0.date == anchor }
                .map { TemplateItem(taskId: $0.taskId, startMinute: $0.startMinute, durationMinutes: $0.durationMinutes) }
            d.settings.openedDates.insert(anchor)
        }
    }

    func clearRecurringRule() {
        mutate { d in
            d.settings.recurringRule = nil
            d.settings.recurringAnchorDate = nil
            d.settings.recurringTemplate = []
        }
    }

    // MARK: - 체크인

    /// 60초 폴링: 오늘 블록 중 종료 시각이 지난 예정 블록을 체크인 대기로 표시하고 하나를 띄운다.
    func pollCheckins(now: Date = Date()) {
        let today = Day.key(now)
        let nowMin = Day.minuteOfDay(now)
        var changed = false
        for i in data.blocks.indices {
            let b = data.blocks[i]
            if b.state == .planned, !b.checkinPending, b.date == today, b.endMinute <= nowMin, data.task(b.taskId) != nil {
                data.blocks[i].checkinPending = true
                changed = true
            }
        }
        if changed { persist() }
        presentNextCheckinIfNeeded()
    }

    private func presentNextCheckinIfNeeded() {
        guard presentedCheckinId == nil, goalPromptTaskId == nil else { return }
        presentedCheckinId = data.blocks
            .filter { $0.checkinPending && $0.state == .planned && data.task($0.taskId) != nil }
            .sorted { ($0.date, $0.startMinute) < ($1.date, $1.startMinute) }
            .first?.id
    }

    /// 완료 → 반복은 횟수+1, 한 번은 완료 처리 / 못했어요 → 블록만 정리. 리뷰 기록.
    func answerCheckin(blockId: UUID, completed: Bool, memo: String) {
        guard let block = block(blockId), let task = task(block.taskId) else {
            presentedCheckinId = nil
            return
        }
        var prompt = false
        mutate { d in
            guard let bi = d.blocks.firstIndex(where: { $0.id == blockId }),
                  let ti = d.tasks.firstIndex(where: { $0.id == task.id }) else { return }
            let attemptsBefore = d.reviews.filter { $0.taskId == task.id }.count
            d.reviews.append(CheckinReview(taskId: task.id, blockId: blockId, date: block.date, completed: completed,
                                           memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                                           occurrence: attemptsBefore + 1))
            d.blocks[bi].checkinPending = false
            d.blocks[bi].state = completed ? .logged : .missed

            var t = d.tasks[ti]
            if completed {
                if t.type == .once {
                    t.done = true
                    t.completedAt = Date()
                } else {
                    t.count += 1
                    if let target = t.target, t.count >= target {
                        // 목표 달성 → 조용히 종료
                        t.recurringEnded = true
                        t.done = true
                        t.completedAt = Date()
                    }
                }
            }
            d.tasks[ti] = t

            if t.isFinished {
                Self.removeFutureBlocks(&d, taskId: t.id)
            } else if t.type == .recurring, let target = t.target,
                      attemptsBefore + 1 >= target, t.count < target, !t.recurringGoalPromptAnswered {
                prompt = true
            }
        }
        if prompt { goalPromptTaskId = task.id }
    }

    /// 리액션 애니메이션이 끝나면 호출 — 모달을 닫고 다음 대기 체크인이 있으면 이어서 띄운다.
    func finishCheckinPresentation() {
        presentedCheckinId = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.presentNextCheckinIfNeeded()
        }
    }

    func answerGoalPrompt(taskId: UUID, keepGoing: Bool) {
        mutate { d in
            guard let i = d.tasks.firstIndex(where: { $0.id == taskId }) else { return }
            d.tasks[i].recurringGoalPromptAnswered = true
            if !keepGoing {
                d.tasks[i].recurringEnded = true
                d.tasks[i].done = true
                d.tasks[i].completedAt = Date()
                Self.removeFutureBlocks(&d, taskId: taskId)
            }
        }
        goalPromptTaskId = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.presentNextCheckinIfNeeded()
        }
    }

    // MARK: - 할 일 / 프로젝트

    func upsertTask(_ task: TaskItem) {
        var t = task
        if t.type == .once {
            t.target = nil
        } else if !t.recurringEnded, let target = t.target, t.count >= target {
            t.recurringEnded = true
            t.done = true
            t.completedAt = Date()
        }
        mutate { d in
            if let i = d.tasks.firstIndex(where: { $0.id == t.id }) {
                d.tasks[i] = t
            } else {
                d.tasks.append(t)
            }
            if t.isFinished { Self.removeFutureBlocks(&d, taskId: t.id) }
        }
    }

    func deleteTask(_ id: UUID) {
        mutate { d in
            d.tasks.removeAll { $0.id == id }
            d.blocks.removeAll { $0.taskId == id }
            d.reviews.removeAll { $0.taskId == id }
            d.settings.recurringTemplate.removeAll { $0.taskId == id }
        }
        if let pid = presentedCheckinId, block(pid) == nil { presentedCheckinId = nil }
    }

    @discardableResult
    func addProject(name: String) -> Project {
        let p = Project(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        mutate { d in d.projects.append(p) }
        return p
    }

    func renameProject(_ id: UUID, name: String) {
        mutate { d in
            guard let i = d.projects.firstIndex(where: { $0.id == id }) else { return }
            d.projects[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// 프로젝트만 지우고 안의 할 일은 '미분류'로 옮긴다.
    func deleteProject(_ id: UUID) {
        mutate { d in
            d.projects.removeAll { $0.id == id }
            for i in d.tasks.indices where d.tasks[i].projectId == id { d.tasks[i].projectId = nil }
        }
    }

    // MARK: - 설정 / 테마

    func updateSettings(_ body: (inout AppSettings) -> Void) {
        mutate { d in body(&d.settings) }
    }

    func selectTheme(_ id: String) {
        updateSettings { $0.colorTheme = id }
    }

    func saveCustomTheme(_ theme: CustomColorTheme) {
        mutate { d in
            if let i = d.customThemes.firstIndex(where: { $0.id == theme.id }) {
                d.customThemes[i] = theme
            } else {
                d.customThemes.append(theme)
            }
            d.settings.colorTheme = theme.id.uuidString
        }
    }

    func deleteCustomTheme(_ id: UUID) {
        mutate { d in
            d.customThemes.removeAll { $0.id == id }
            if d.settings.colorTheme == id.uuidString { d.settings.colorTheme = ThemeIds.mono }
        }
    }

    // MARK: - 데이터

    /// 할 일/프로젝트/일정/기록/반복 설정을 지운다(테마·환경설정은 유지).
    func resetData() {
        presentedCheckinId = nil
        goalPromptTaskId = nil
        mutate { d in
            let fresh = AppData.seed()
            d.projects = fresh.projects
            d.tasks = []
            d.blocks = []
            d.reviews = []
            d.settings.recurringRule = nil
            d.settings.recurringAnchorDate = nil
            d.settings.recurringTemplate = []
            d.settings.openedDates = []
        }
    }

    func exportJSON() -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? e.encode(data)) ?? Data()
    }

    func importJSON(_ raw: Data) throws {
        let decoded = try SharedStore.decoder.decode(AppData.self, from: raw)
        presentedCheckinId = nil
        goalPromptTaskId = nil
        data = decoded
        persist()
    }
}
