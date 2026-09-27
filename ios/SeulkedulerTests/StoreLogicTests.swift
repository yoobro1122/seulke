import XCTest
import SwiftUI
@testable import Seulkeduler

@MainActor
final class StoreLogicTests: XCTestCase {
    private var today: String { Day.todayKey }
    private var future: String { Day.add(2, to: today) }

    private func makeStore(_ tasks: [TaskItem] = [], blocks: [ScheduleBlock] = []) -> AppStore {
        var d = AppData.seed()
        d.tasks = tasks
        d.blocks = blocks
        return AppStore(inMemory: d)
    }

    // MARK: 스냅 / 자석

    func testGridSnap() {
        XCTAssertEqual(TimelineMath.snap(7), 0)
        XCTAssertEqual(TimelineMath.snap(8), 15)
        XCTAssertEqual(TimelineMath.snap(612), 615)
    }

    func testMagnetSnapsToNeighborEdgeWithin20Minutes() {
        let other = ScheduleBlock(taskId: UUID(), date: today, startMinute: 600, durationMinutes: 60) // 10:00-11:00
        // 11:12 시작으로 끌면 11:00(다른 블록 끝)에 딱 붙음
        XCTAssertEqual(TimelineMath.proposeMove(rawStart: 672, duration: 30, others: [other]), 660)
        // 끝이 9:50 → 10:00 시작에 붙도록 9:30 시작
        XCTAssertEqual(TimelineMath.proposeMove(rawStart: 560, duration: 30, others: [other]), 570)
        // 25분 떨어지면 자석 없이 그리드 스냅
        XCTAssertEqual(TimelineMath.proposeMove(rawStart: 685, duration: 30, others: [other]), 690)
    }

    func testResizeMagnetAndMinimum() {
        let other = ScheduleBlock(taskId: UUID(), date: today, startMinute: 720, durationMinutes: 30)
        XCTAssertEqual(TimelineMath.proposeResizeEnd(rawEnd: 705, start: 600, others: [other]), 720)
        XCTAssertEqual(TimelineMath.proposeResizeEnd(rawEnd: 590, start: 600, others: []), 615)
    }

    // MARK: 블록 배치 / 병합

    func testPlaceBlockCreates30MinutesAndClampsBeforeNextBlock() {
        let a = TaskItem(title: "A")
        let b = TaskItem(title: "B")
        let store = makeStore([a, b], blocks: [ScheduleBlock(taskId: b.id, date: future, startMinute: 615, durationMinutes: 60)])
        XCTAssertTrue(store.placeBlock(taskId: a.id, date: future, start: 540))
        XCTAssertEqual(store.blocks(on: future).first { $0.taskId == a.id }?.durationMinutes, 30)
        // 10:00에 놓으면 10:15(B 시작)까지만
        XCTAssertTrue(store.placeBlock(taskId: a.id, date: future, start: 600))
        // B 안쪽에는 못 놓음
        XCTAssertFalse(store.placeBlock(taskId: a.id, date: future, start: 630))
    }

    func testAdjacentBlocksOfSameTaskMerge() {
        let a = TaskItem(title: "A")
        let store = makeStore([a])
        store.placeBlock(taskId: a.id, date: future, start: 540)
        store.placeBlock(taskId: a.id, date: future, start: 570)
        let blocks = store.blocks(on: future)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].startMinute, 540)
        XCTAssertEqual(blocks[0].durationMinutes, 60)
    }

    func testAdjacentBlocksOfDifferentTasksDoNotMerge() {
        let a = TaskItem(title: "A")
        let b = TaskItem(title: "B")
        let store = makeStore([a, b])
        store.placeBlock(taskId: a.id, date: future, start: 540)
        store.placeBlock(taskId: b.id, date: future, start: 570)
        XCTAssertEqual(store.blocks(on: future).count, 2)
    }

    func testMoveOntoOtherTaskIsRejected() {
        let a = TaskItem(title: "A")
        let b = TaskItem(title: "B")
        let ba = ScheduleBlock(taskId: a.id, date: future, startMinute: 540, durationMinutes: 30)
        let bb = ScheduleBlock(taskId: b.id, date: future, startMinute: 600, durationMinutes: 30)
        let store = makeStore([a, b], blocks: [ba, bb])
        XCTAssertFalse(store.updateBlock(ba.id, start: 585, duration: 30))
        XCTAssertEqual(store.block(ba.id)?.startMinute, 540)
        XCTAssertTrue(store.updateBlock(ba.id, start: 570, duration: 30))
    }

    func testRemoveBlockKeepsTask() {
        let a = TaskItem(title: "A")
        let blk = ScheduleBlock(taskId: a.id, date: future, startMinute: 540, durationMinutes: 30)
        let store = makeStore([a], blocks: [blk])
        store.removeBlock(blk.id)
        XCTAssertNil(store.block(blk.id))
        XCTAssertNotNil(store.task(a.id))
    }

    // MARK: 체크인 / 목표

    func testCheckinCompletesOnceTask() {
        let t = TaskItem(title: "한 번")
        let blk = ScheduleBlock(taskId: t.id, date: today, startMinute: 0, durationMinutes: 15, checkinPending: true)
        let store = makeStore([t], blocks: [blk])
        store.answerCheckin(blockId: blk.id, completed: true, memo: " 끝 ")
        XCTAssertTrue(store.task(t.id)!.done)
        XCTAssertEqual(store.block(blk.id)?.state, .logged)
        XCTAssertEqual(store.reviews(for: t.id).first?.memo, "끝")
    }

    func testMissedCheckinKeepsTaskOpen() {
        let t = TaskItem(title: "한 번")
        let blk = ScheduleBlock(taskId: t.id, date: today, startMinute: 0, durationMinutes: 15, checkinPending: true)
        let store = makeStore([t], blocks: [blk])
        store.answerCheckin(blockId: blk.id, completed: false, memo: "")
        XCTAssertFalse(store.task(t.id)!.done)
        XCTAssertEqual(store.block(blk.id)?.state, .missed)
        XCTAssertEqual(store.reviews(for: t.id).first?.completed, false)
    }

    func testRecurringEndsSilentlyWhenTargetReachedAndClearsFutureBlocks() {
        let t = TaskItem(title: "반복", type: .recurring, target: 2, count: 1)
        let now = ScheduleBlock(taskId: t.id, date: today, startMinute: 0, durationMinutes: 15, checkinPending: true)
        let later = ScheduleBlock(taskId: t.id, date: future, startMinute: 600, durationMinutes: 30)
        let store = makeStore([t], blocks: [now, later])
        store.answerCheckin(blockId: now.id, completed: true, memo: "")
        let saved = store.task(t.id)!
        XCTAssertEqual(saved.count, 2)
        XCTAssertTrue(saved.recurringEnded)
        XCTAssertNil(store.goalPromptTaskId)
        XCTAssertNil(store.block(later.id), "미래 블록 정리")
    }

    func testGoalPromptAppearsExactlyOnceAndNoEndsTask() {
        var t = TaskItem(title: "반복", type: .recurring, target: 2)
        t.count = 0
        let b1 = ScheduleBlock(taskId: t.id, date: today, startMinute: 0, durationMinutes: 15, checkinPending: true)
        let b2 = ScheduleBlock(taskId: t.id, date: today, startMinute: 30, durationMinutes: 15, checkinPending: true)
        let fut = ScheduleBlock(taskId: t.id, date: future, startMinute: 600, durationMinutes: 30)
        let store = makeStore([t], blocks: [b1, b2, fut])

        store.answerCheckin(blockId: b1.id, completed: false, memo: "")
        XCTAssertNil(store.goalPromptTaskId, "시도 1 < 목표 2")
        store.answerCheckin(blockId: b2.id, completed: true, memo: "")
        XCTAssertEqual(store.goalPromptTaskId, t.id, "시도 2 = 목표인데 완료 1 → 확인 모달")

        store.answerGoalPrompt(taskId: t.id, keepGoing: false)
        XCTAssertTrue(store.task(t.id)!.recurringEnded)
        XCTAssertNil(store.block(fut.id))
    }

    func testGoalPromptYesDoesNotAskAgain() {
        let t = TaskItem(title: "반복", type: .recurring, target: 1)
        let blocks = (0..<3).map { ScheduleBlock(taskId: t.id, date: today, startMinute: $0 * 30, durationMinutes: 15, checkinPending: true) }
        let store = makeStore([t], blocks: blocks)
        store.answerCheckin(blockId: blocks[0].id, completed: false, memo: "")
        XCTAssertEqual(store.goalPromptTaskId, t.id)
        store.answerGoalPrompt(taskId: t.id, keepGoing: true)
        store.answerCheckin(blockId: blocks[1].id, completed: false, memo: "")
        XCTAssertNil(store.goalPromptTaskId)
        store.answerCheckin(blockId: blocks[2].id, completed: true, memo: "")
        XCTAssertTrue(store.task(t.id)!.recurringEnded, "완료가 목표에 닿으면 종료")
        XCTAssertEqual(store.reviews(for: t.id).map(\.occurrence).sorted(), [1, 2, 3])
    }

    // MARK: 반복 규칙 / 템플릿

    func testRulePhrasesAndMatching() {
        // 2026-09-23 = 넷째 주 수요일
        let rule = RecurringRule.options(for: "2026-09-23")[3]
        XCTAssertEqual(rule.phrase, "매월 넷째 주 수요일")
        XCTAssertTrue(rule.matches("2026-10-28"))
        XCTAssertFalse(rule.matches("2026-10-21"))
        XCTAssertTrue(RecurringRule.monthlyLastDay.matches("2026-02-28"))
        XCTAssertFalse(RecurringRule.monthlyLastDay.matches("2026-09-29"))
        XCTAssertEqual(RecurringRule.weekly(weekday: 4).phrase, "매주 수요일")
        XCTAssertTrue(RecurringRule.weekly(weekday: 4).matches("2026-09-30"))
    }

    func testTemplateFillsOnlyUnopenedTodayOrFutureDates() {
        let t = TaskItem(title: "매일")
        let store = makeStore([t], blocks: [ScheduleBlock(taskId: t.id, date: today, startMinute: 480, durationMinutes: 60)])
        store.setRecurringRule(.daily, anchor: today)

        let past = Day.add(-3, to: today)
        store.openDay(past)
        XCTAssertTrue(store.blocks(on: past).isEmpty, "과거 날짜는 자동 채움 대상 아님")

        let tomorrow = Day.add(1, to: today)
        store.openDay(tomorrow)
        XCTAssertEqual(store.blocks(on: tomorrow).map(\.startMinute), [480])

        // 이미 열어본 날은 다시 채우지 않음
        store.removeBlock(store.blocks(on: tomorrow)[0].id)
        store.openDay(tomorrow)
        XCTAssertTrue(store.blocks(on: tomorrow).isEmpty)

        XCTAssertEqual(store.blocks(on: today).count, 1, "기준일 중복 채움 없음")
    }

    func testNewRuleReplacesOldTemplate() {
        let a = TaskItem(title: "A")
        let b = TaskItem(title: "B")
        let d1 = Day.add(1, to: today)
        let store = makeStore([a, b], blocks: [
            ScheduleBlock(taskId: a.id, date: today, startMinute: 60, durationMinutes: 30),
            ScheduleBlock(taskId: b.id, date: d1, startMinute: 120, durationMinutes: 30)
        ])
        store.setRecurringRule(.daily, anchor: today)
        store.setRecurringRule(.weekly(weekday: Day.weekday(d1)), anchor: d1)
        XCTAssertEqual(store.settings.recurringTemplate.map(\.taskId), [b.id])
        XCTAssertEqual(store.settings.recurringAnchorDate, d1)
    }

    func testFinishedTasksAreSkippedByTemplate() {
        var t = TaskItem(title: "끝남")
        t.done = true
        var d = AppData.seed()
        d.tasks = [t]
        d.settings.recurringRule = .daily
        d.settings.recurringAnchorDate = today
        d.settings.recurringTemplate = [TemplateItem(taskId: t.id, startMinute: 0, durationMinutes: 30)]
        XCTAssertTrue(d.templateBlocks(on: future).isEmpty)
    }

    // MARK: 알림 / 테마 / 백업

    func testNotificationScheduleTable() {
        XCTAssertEqual(NotificationService.offsetsByImportance[1], [])
        XCTAssertEqual(NotificationService.offsetsByImportance[2], [])
        XCTAssertEqual(NotificationService.offsetsByImportance[3], [0])
        XCTAssertEqual(NotificationService.offsetsByImportance[4], [10, 0])
        XCTAssertEqual(NotificationService.offsetsByImportance[5], [30, 10, 0])
    }

    func testSwatchIndexIsStable() {
        let id = UUID(uuidString: "5B9C4B8E-1F0A-4C39-9E43-7D5E2E0B6A11")!
        let i = ThemeCatalog.swatchIndex(for: id)
        XCTAssertEqual(i, ThemeCatalog.swatchIndex(for: id))
        XCTAssertTrue((0..<7).contains(i))
    }

    func testSwatchOverrideOnlyChangesThatSlot() {
        var t = CustomColorTheme(baseHue: 200)
        let before = ThemeCatalog.palette(for: t)
        t.presetHueOverrides[2] = 20
        let after = ThemeCatalog.palette(for: t)
        XCTAssertEqual(before.swatches[0], after.swatches[0])
        XCTAssertNotEqual(before.swatches[2], after.swatches[2])
        XCTAssertEqual(after.swatches[2].h, 20.0 / 360, accuracy: 0.0001)
    }

    func testDeletingSelectedThemeFallsBackToMono() {
        let store = makeStore()
        let theme = store.data.customThemes[0]
        store.selectTheme(theme.id.uuidString)
        store.deleteCustomTheme(theme.id)
        XCTAssertEqual(store.settings.colorTheme, ThemeIds.mono)
    }

    func testBackupRoundTrip() throws {
        let t = TaskItem(title: "백업", type: .recurring, target: nil, importance: 5, linkedApp: "notion")
        let store = makeStore([t], blocks: [ScheduleBlock(taskId: t.id, date: today, startMinute: 90, durationMinutes: 45)])
        store.setRecurringRule(.monthlyNthWeekday(nth: 2, weekday: 3), anchor: today)
        let json = store.exportJSON()

        let other = makeStore()
        try other.importJSON(json)
        XCTAssertEqual(other.task(t.id)?.linkedApp, "notion")
        XCTAssertNil(other.task(t.id)?.target)
        XCTAssertEqual(other.blocks(on: today).first?.durationMinutes, 45)
        XCTAssertEqual(other.settings.recurringRule, .monthlyNthWeekday(nth: 2, weekday: 3))
    }

    func testDeleteProjectMovesTasksToUnfiled() {
        let store = makeStore()
        let p = store.addProject(name: "임시")
        store.upsertTask(TaskItem(title: "x", projectId: p.id))
        store.deleteProject(p.id)
        XCTAssertNil(store.data.tasks[0].projectId)
    }
}

/// 위젯 화면을 이미지로 렌더링해 SCREENSHOT_DIR에 저장(시각 확인용)
@MainActor
final class WidgetRenderTests: XCTestCase {
    func testRenderWidget() throws {
        var data = DemoData.make()
        for (i, theme) in [ThemeIds.mono, data.customThemes[0].id.uuidString, data.customThemes[2].id.uuidString].enumerated() {
            data.settings.colorTheme = theme
            let view = SeulWidgetView(entry: DialEntry(date: Date(), data: data)).frame(width: 170, height: 170)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let png = try XCTUnwrap(renderer.uiImage?.pngData())
            if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
                try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("widget-\(i).png"))
            }
            XCTAssertGreaterThan(png.count, 1000)
        }
    }
}
