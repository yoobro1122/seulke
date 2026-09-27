import XCTest

/// 실제 화면을 조작하며 주요 흐름을 확인하고, 단계별 스크린샷을 SCREENSHOT_DIR(없으면 첨부)로 남긴다.
final class SeulkedulerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ seed: String = "-seedDemo") {
        app.launchArguments = [seed]
        app.launch()
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// "제목, HH:mm–HH:mm" 라벨에서 (시작분, 끝분)
    private func times(_ label: String) -> (Int, Int) {
        let part = label.components(separatedBy: ", ").last ?? ""
        let mins = part.components(separatedBy: "–").map { t -> Int in
            let hm = t.split(separator: ":").compactMap { Int($0) }
            return hm.count == 2 ? hm[0] * 60 + hm[1] : -1
        }
        return (mins.first ?? -1, mins.last ?? -1)
    }

    private func tab(_ name: String) {
        app.buttons[name].firstMatch.tap()
    }

    private func dismissCheckinIfShown(completed: Bool = true) {
        let title = app.staticTexts["완료하셨나요?"]
        if title.waitForExistence(timeout: 3) {
            app.buttons[completed ? "완료했어요" : "못했어요"].tap()
            XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        }
    }

    func test1_CheckinThenTodayViews() {
        launch()
        let title = app.staticTexts["완료하셨나요?"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "지난 블록 체크인 모달 자동 표시")
        shot("01-checkin")
        let memo = app.textFields["한 줄 메모 (선택)"]
        memo.tap()
        memo.typeText("집중 잘 됨")
        app.buttons["완료했어요"].tap()
        sleep(1)
        shot("02-reaction")
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "리액션 후 자동 닫힘")
        sleep(1)
        shot("03-today-list")

        app.buttons["원형"].tap()
        XCTAssertTrue(app.staticTexts["지금"].waitForExistence(timeout: 3))
        shot("04-today-dial")

        app.buttons["달력"].tap()
        XCTAssertTrue(app.buttons["이전 달"].waitForExistence(timeout: 3))
        for d in ["1", "15", "30"] {
            XCTAssertTrue(app.buttons[d].exists, "달력에 \(d)일 표시")
        }
        shot("05-today-calendar")
        app.buttons["다음 날"].firstMatch.tap()
        app.buttons["오늘"].firstMatch.tap()
    }

    func test2_TasksTabAndDetail() {
        launch()
        dismissCheckinIfShown(completed: false)
        tab("할일")
        XCTAssertTrue(app.staticTexts["아침 운동"].waitForExistence(timeout: 3))
        shot("06-tasks")
        app.staticTexts["아침 운동"].tap()
        XCTAssertTrue(app.staticTexts["할 일 수정"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["3/10 완료"].exists, "진행 현황 알약 태그")
        shot("07-task-form-top")
        app.swipeUp()
        app.swipeUp()
        shot("08-task-form-progress")
        app.buttons["닫기"].tap()
    }

    func test3_CreateTaskAndPlaceFromEventPicker() {
        launch()
        dismissCheckinIfShown()
        tab("할일")
        app.buttons["할 일 추가"].tap()
        let field = app.textFields["무엇을 할까요?"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("UI 테스트 할 일\n")
        app.buttons["반복"].tap()
        app.buttons["목표 늘리기"].tap()
        shot("09-new-task-form")
        app.buttons["form-save-top"].tap()
        XCTAssertTrue(app.staticTexts["UI 테스트 할 일"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["매일 · 0/11"].exists, "목표 +1 반영")

        tab("오늘")
        let slot = app.otherElements["slot-120"]
        XCTAssertTrue(slot.waitForExistence(timeout: 3))
        app.buttons["이전 날"].firstMatch.tap()
        app.buttons["다음 날"].firstMatch.tap()
        slot.press(forDuration: 1.0)
        XCTAssertTrue(app.staticTexts["이벤트 선택"].waitForExistence(timeout: 3), "빈 시간 길게 누르기 → 이벤트 선택")
        shot("10-event-picker")
        app.staticTexts["UI 테스트 할 일"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["이벤트 선택"].waitForNonExistence(timeout: 3))
        sleep(1)
        shot("11-placed-block")
    }

    func test4_RecurrenceSetup() {
        launch()
        dismissCheckinIfShown()
        app.buttons["반복 설정"].tap()
        XCTAssertTrue(app.buttons["설정 완료"].waitForExistence(timeout: 3))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '매주'")).firstMatch.tap()
        shot("12-recurrence")
        app.buttons["설정 완료"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '반복합니다.'")).firstMatch.waitForExistence(timeout: 3))
        shot("13-recurrence-confirm")
        app.buttons["확인"].tap()
        XCTAssertTrue(app.buttons["설정 완료"].waitForNonExistence(timeout: 3))
        // 다음 주 같은 요일을 열면 자동으로 채워진다(중간 날짜는 매주 규칙이라 비어 있음)
        app.buttons["다음 날"].firstMatch.tap()
        sleep(1)
        XCTAssertFalse(app.descendants(matching: .any)["block-논문 읽기"].exists)
        for _ in 0..<6 { app.buttons["다음 날"].firstMatch.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["block-논문 읽기"].waitForExistence(timeout: 3), "템플릿 자동 채움")
        sleep(1)
        shot("14-autofilled-next-week")
    }

    func test5_SettingsAndThemeEditor() {
        launch()
        dismissCheckinIfShown()
        tab("설정")
        XCTAssertTrue(app.staticTexts["색상 테마"].waitForExistence(timeout: 3))
        app.swipeUp()
        app.buttons["새 테마"].tap()
        XCTAssertTrue(app.buttons["저장하고 적용"].waitForExistence(timeout: 3))
        shot("15-theme-editor")
        app.buttons["저장하고 적용"].tap()
        sleep(1)
        shot("16-settings-new-theme")
        tab("오늘")
        sleep(1)
        shot("17-today-new-theme")
    }

    func test7_DragMoveResizeAndDeleteBlock() {
        launch()
        dismissCheckinIfShown()
        let block = app.descendants(matching: .any)["block-장보기"]
        XCTAssertTrue(block.waitForExistence(timeout: 3))
        let before = block.label
        // 길게 누른 뒤 한 시간(64pt) 아래로 끌기
        let start = block.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        start.press(forDuration: 0.6, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 64)),
                    withVelocity: 120, thenHoldForDuration: 0.4)
        sleep(1)
        let moved = app.descendants(matching: .any)["block-장보기"].label
        XCTAssertNotEqual(before, moved, "이동 후 시간 변경: \(before) → \(moved)")
        let (s0, e0) = times(before)
        let (s1, e1) = times(moved)
        XCTAssertEqual(s1 - s0, 60, "한 시간 아래로 이동: \(moved)")
        XCTAssertEqual(e1 - s1, e0 - s0, "길이 유지")
        shot("19-after-move")

        // 하단 그립으로 30분 늘리기
        let grip = app.descendants(matching: .any)["block-장보기"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0))
            .withOffset(CGVector(dx: 0, dy: 6))
        grip.press(forDuration: 0.1, thenDragTo: grip.withOffset(CGVector(dx: 0, dy: 32)), withVelocity: 150, thenHoldForDuration: 0.3)
        sleep(1)
        let resized = app.descendants(matching: .any)["block-장보기"].label
        let (s2, e2) = times(resized)
        XCTAssertEqual(s2, s1, "리사이즈는 시작 유지")
        XCTAssertEqual(e2 - e1, 30, "30분 늘어남: \(resized)")

        // 블록 탭 → 상세 모달
        app.descendants(matching: .any)["block-논문 읽기"].tap()
        XCTAssertTrue(app.buttons["할 일 수정"].waitForExistence(timeout: 3), "블록 상세 모달")
        shot("20-block-detail")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(app.buttons["할 일 수정"].waitForNonExistence(timeout: 3))

        app.buttons["delete-장보기"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["block-장보기"].waitForNonExistence(timeout: 3), "× 로 스케줄에서 삭제")
        tab("할일")
        XCTAssertTrue(app.staticTexts["장보기"].waitForExistence(timeout: 3), "할 일 자체는 남아 있음")
    }

    func test8_DragTaskCardFromSheetToTimeline() {
        launch()
        dismissCheckinIfShown()
        // 시트를 half로 올리고 '장보기' 카드를 타임라인 위쪽 빈 곳으로 끌어다 놓기
        app.buttons["sheet-toggle"].tap()
        sleep(1)
        shot("21-sheet-half")
        let before = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'block-장보기'")).count
        let card = app.staticTexts.matching(NSPredicate(format: "label == '장보기'")).element(boundBy: 0)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.55))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: target, withVelocity: 300, thenHoldForDuration: 1.0)
        sleep(2)
        shot("22-after-card-drop")
        let after = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'block-장보기'")).count
        XCTAssertEqual(after, before + 1, "카드 드롭으로 30분 블록 생성")

        // full 단계는 탭바를 덮는다
        app.buttons["sheet-toggle"].tap()
        app.buttons["sheet-toggle"].tap()
        sleep(1)
        shot("23-sheet-full")
    }

    func test6_EmptyStateSheet() {
        launch("-seedEmpty")
        XCTAssertTrue(app.staticTexts["할 일"].waitForExistence(timeout: 3))
        shot("18-empty-today")
    }
}

extension XCUIElement {
    /// Xcode 14에는 없는 waitForNonExistence 대체
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }
}
