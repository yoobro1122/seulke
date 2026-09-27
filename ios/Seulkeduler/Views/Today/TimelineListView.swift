import SwiftUI
import UniformTypeIdentifiers

/// 24시간 목록 타임라인.
/// - 블록 몸통: 짧게 길게 누른 뒤 드래그 = 이동 / 하단 그립 드래그 = 리사이즈 (15분 스냅 + 20분 자석)
/// - 빈 시간대 길게 누르기 = 이벤트 선택 모달
/// - 바텀시트 할 일 카드를 끌어와 놓으면 30분 블록 생성(고스트 미리보기)
struct TimelineListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var today: TodayState
    @Environment(\.seul) private var c

    let dateKey: String
    let bottomInset: CGFloat
    var onLongPressSlot: (Int) -> Void
    var onTapBlock: (ScheduleBlock) -> Void

    static let hourHeight: CGFloat = 64
    static let topPad: CGFloat = 14
    private let labelWidth: CGFloat = 56
    private let trailingPad: CGFloat = 16

    struct BlockDrag: Equatable {
        var id: UUID
        var start: Int
        var duration: Int
    }

    @State private var drag: BlockDrag?
    /// 제스처가 취소되면(스크롤 등) 자동으로 false가 되어 드래그 미리보기를 정리한다.
    @GestureState private var gestureActive = false
    @State private var ghostStart: Int?
    @State private var now = Date()

    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var isToday: Bool { dateKey == Day.key(now) }
    private var nowMinute: Int { Day.minuteOfDay(now) }

    static func y(_ minute: Int) -> CGFloat { topPad + CGFloat(minute) / 60 * hourHeight }
    static func height(_ duration: Int) -> CGFloat { CGFloat(duration) / 60 * hourHeight }

    var body: some View {
        GeometryReader { geo in
            let colWidth = max(80, geo.size.width - labelWidth - trailingPad)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        hourGrid(width: geo.size.width)
                        slotLayer(width: colWidth)
                        if let g = ghostStart { ghost(start: g, width: colWidth) }
                        ForEach(store.blocks(on: dateKey)) { b in
                            blockView(b, width: colWidth)
                        }
                        if isToday { nowLine(width: geo.size.width) }
                        anchors
                    }
                    .frame(width: geo.size.width, height: Self.y(1440) + 24 + bottomInset, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.plainText], delegate: TaskDropDelegate(ghost: $ghostStart, onDrop: handleDrop))
                }
                .scrollDisabled(drag != nil)
                .onAppear { autoScroll(proxy) }
                .onChange(of: dateKey) { _ in autoScroll(proxy) }
            }
        }
        .onReceive(clock) { now = $0 }
        .onChange(of: gestureActive) { active in
            if !active { drag = nil }
        }
    }

    // MARK: 자동 스크롤: 오늘이면 현재 시각이 화면 위 1/5 지점

    private func autoScroll(_ proxy: ScrollViewProxy) {
        // 첫 레이아웃이 끝난 뒤에 스크롤해야 위치가 정확하다
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if dateKey == Day.todayKey {
                proxy.scrollTo("q\(Day.minuteOfDay(Date()) / 15)", anchor: UnitPoint(x: 0.5, y: 0.2))
            } else {
                proxy.scrollTo("q32", anchor: .top)
            }
        }
    }

    /// 스크롤 기준점: 실제 레이아웃 위치를 갖도록 15분 단위 행을 VStack으로 쌓는다.
    private var anchors: some View {
        VStack(spacing: 0) {
            ForEach(0..<96, id: \.self) { i in
                Color.clear.frame(width: 1, height: Self.hourHeight / 4).id("q\(i)")
            }
        }
        .padding(.top, Self.topPad)
        .allowsHitTesting(false)
    }

    // MARK: 그리드

    private func hourGrid(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<25, id: \.self) { h in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", h))
                        .font(SeulFont.mono(10))
                        .foregroundColor(c.inkFaint.color)
                        .frame(width: labelWidth - 12, alignment: .trailing)
                        .offset(y: -7)
                    Rectangle()
                        .fill(c.line.color)
                        .frame(height: 1)
                }
                .frame(height: h == 24 ? 1 : Self.hourHeight, alignment: .top)
            }
        }
        .padding(.top, Self.topPad)
        .padding(.trailing, trailingPad)
        .frame(width: width, alignment: .leading)
        .allowsHitTesting(false)
    }

    /// 15분 단위 빈 슬롯. 길게 누르면 이벤트 선택 모달.
    private func slotLayer(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<96, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: width, height: Self.hourHeight / 4)
                    .onLongPressGesture(minimumDuration: 0.45) {
                        onLongPressSlot(i * 15)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(Day.hhmm(i * 15)) 빈 시간")
                    .accessibilityIdentifier("slot-\(i * 15)")
                    .accessibilityAction(named: "이벤트 추가") { onLongPressSlot(i * 15) }
            }
        }
        .padding(.top, Self.topPad)
        .padding(.leading, labelWidth)
    }

    private func nowLine(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(Day.hhmm(nowMinute))
                .font(SeulFont.monoMedium(10))
                .foregroundColor(c.accent.color)
                .padding(.horizontal, 4)
                .background(c.bg.color)
                .frame(width: labelWidth - 4, alignment: .trailing)
            Circle().fill(c.accent.color).frame(width: 8, height: 8)
            Rectangle().fill(c.accent.color).frame(height: 1.5)
        }
        .padding(.trailing, trailingPad)
        .frame(width: width, height: 12)
        .padding(.top, Self.y(nowMinute) - 6)
        .allowsHitTesting(false)
        .zIndex(20)
    }

    // MARK: 드롭(할 일 카드 → 30분 블록)

    private func ghost(start: Int, width: CGFloat) -> some View {
        let color = today.draggingTaskId.map { c.swatch(for: $0) } ?? c.accent
        let title = today.draggingTaskId.flatMap { store.task($0)?.title } ?? "여기에 놓기"
        return RoundedRectangle(cornerRadius: Radius.scheduleBlock, style: .continuous)
            .fill(color.color.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: Radius.scheduleBlock, style: .continuous)
                .strokeBorder(color.color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .overlay(alignment: .topLeading) {
                Text("\(Day.hhmm(start)) · \(title)")
                    .font(SeulFont.medium(12))
                    .foregroundColor(c.ink.color)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
            .frame(width: width, height: Self.height(30) - 2)
            .padding(.leading, labelWidth)
            .padding(.top, Self.y(start) + 1)
            .allowsHitTesting(false)
    }

    private func handleDrop(minute: Int, providers: [NSItemProvider]) {
        if let id = today.draggingTaskId {
            if !store.placeBlock(taskId: id, date: dateKey, start: minute) {
                store.haptic(.warning) // 이미 다른 일정이 있는 자리
            }
            today.draggingTaskId = nil
            return
        }
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String, let id = UUID(uuidString: s) else { return }
            DispatchQueue.main.async {
                store.placeBlock(taskId: id, date: dateKey, start: minute)
            }
        }
    }

    // MARK: 블록

    private func neighbors(of b: ScheduleBlock) -> [ScheduleBlock] {
        store.blocks(on: dateKey).filter { $0.id != b.id }
    }

    private func blockView(_ b: ScheduleBlock, width: CGFloat) -> some View {
        let active = drag?.id == b.id ? drag : nil
        let start = active?.start ?? b.startMinute
        let duration = active?.duration ?? b.durationMinutes
        let h = max(Self.height(duration) - 2, 14)
        let isPast = dateKey < Day.key(now) || (isToday && b.endMinute <= nowMinute)

        return TimelineBlockCard(block: b, task: store.task(b.taskId), start: start, duration: duration,
                                 height: h, lifted: active != nil, isPast: isPast,
                                 hasReview: store.review(for: b) != nil)
            .frame(width: width, height: h)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(store.task(b.taskId)?.title ?? "삭제된 할 일"), \(Day.hhmm(start))–\(Day.hhmm(start + duration))")
            .accessibilityIdentifier("block-\(store.task(b.taskId)?.title ?? "")")
            .accessibilityAddTraits(.isButton)
            .contentShape(RoundedRectangle(cornerRadius: Radius.scheduleBlock, style: .continuous))
            // 탭을 안쪽 onTapGesture로 두면 길게 누르기-드래그가 막히므로 동시 제스처로 붙인다
            .gesture(moveGesture(b))
            .simultaneousGesture(TapGesture().onEnded { if drag == nil { onTapBlock(b) } })
            .overlay(alignment: .bottom) { resizeGrip(b) }
            .overlay(alignment: .topTrailing) {
                deleteButton(b).accessibilityIdentifier("delete-\(store.task(b.taskId)?.title ?? "")")
            }
            .padding(.leading, labelWidth)
            .padding(.top, Self.y(start) + 1)
            .zIndex(active != nil ? 10 : 1)
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.9), value: active)
    }

    private func moveGesture(_ b: ScheduleBlock) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($gestureActive) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let dragValue) = value else { return }
                let dy = Double(dragValue?.translation.height ?? 0)
                let raw = Double(b.startMinute) + dy / Double(Self.hourHeight) * 60
                let start = TimelineMath.proposeMove(rawStart: raw, duration: b.durationMinutes, others: neighbors(of: b))
                drag = BlockDrag(id: b.id, start: start, duration: b.durationMinutes)
            }
            .onEnded { _ in
                if let d = drag, d.id == b.id, d.start != b.startMinute {
                    store.updateBlock(b.id, start: d.start, duration: d.duration)
                }
                drag = nil
            }
    }

    /// 하단 그립: 보이는 건 작은 캡슐, 히트 영역은 44pt(블록 아래로 삐져나옴)
    private func resizeGrip(_ b: ScheduleBlock) -> some View {
        ZStack(alignment: .top) {
            Color.white.opacity(0.001)
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: 26, height: 4)
                .padding(.top, 8)
        }
        .frame(width: 72, height: Touch.min)
        .alignmentGuide(.bottom) { d in d[.bottom] - 28 }
        .highPriorityGesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .updating($gestureActive) { _, state, _ in state = true }
                .onChanged { v in
                    let raw = Double(b.endMinute) + Double(v.translation.height) / Double(Self.hourHeight) * 60
                    let end = TimelineMath.proposeResizeEnd(rawEnd: raw, start: b.startMinute, others: neighbors(of: b))
                    drag = BlockDrag(id: b.id, start: b.startMinute, duration: end - b.startMinute)
                }
                .onEnded { _ in
                    if let d = drag, d.id == b.id, d.duration != b.durationMinutes {
                        store.updateBlock(b.id, start: d.start, duration: d.duration)
                    }
                    drag = nil
                }
        )
    }

    /// 우상단 ×: 스케줄에서만 삭제(할 일은 유지)
    private func deleteButton(_ b: ScheduleBlock) -> some View {
        Button {
            store.haptic(.warning)
            store.removeBlock(b.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.black.opacity(0.2)))
                .frame(width: Touch.min, height: Touch.min)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("스케줄에서 삭제")
        .alignmentGuide(.top) { d in d[.top] + 9 }
        .alignmentGuide(.trailing) { d in d[.trailing] - 9 }
    }
}

struct TimelineBlockCard: View {
    @Environment(\.seul) private var c
    let block: ScheduleBlock
    let task: TaskItem?
    let start: Int
    let duration: Int
    let height: CGFloat
    let lifted: Bool
    let isPast: Bool
    let hasReview: Bool

    var body: some View {
        let base = c.swatch(for: block.taskId)
        let tone = (block.state == .missed || (isPast && block.state == .planned)) ? base.muted(0.5) : base
        let compact = height < 34

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.scheduleBlock, style: .continuous)
                .fill(c.toneGradient(tone))
            HStack(alignment: .top, spacing: 6) {
                if hasReview {
                    Circle().fill(Color.white).frame(width: 6, height: 6).padding(.top, compact ? 4 : 6)
                }
                if compact {
                    Text("\(task?.title ?? "삭제된 할 일")  \(Day.hhmm(start))")
                        .font(SeulFont.medium(11))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if block.state == .logged {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            Text(task?.title ?? "삭제된 할 일")
                                .font(SeulFont.medium(13))
                                .lineLimit(height > 60 ? 2 : 1)
                        }
                        Text("\(Day.hhmm(start))–\(Day.hhmm(start + duration))")
                            .font(SeulFont.mono(10))
                            .opacity(0.85)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 28)
            .padding(.top, compact ? 1 : 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.scheduleBlock, style: .continuous))
        .shadow(color: .black.opacity(lifted ? 0.22 : 0.05), radius: lifted ? 10 : 2, y: lifted ? 6 : 1)
        .scaleEffect(lifted ? 1.02 : 1)
    }
}

struct TaskDropDelegate: DropDelegate {
    @Binding var ghost: Int?
    let onDrop: (Int, [NSItemProvider]) -> Void

    private func minute(_ info: DropInfo) -> Int {
        let m = Double(info.location.y - TimelineListView.topPad) / Double(TimelineListView.hourHeight) * 60 - 15
        return min(max(TimelineMath.snap(m), 0), 1440 - 30)
    }

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [UTType.plainText]) }

    func dropEntered(info: DropInfo) { ghost = minute(info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let m = minute(info)
        if ghost != m { ghost = m }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) { ghost = nil }

    func performDrop(info: DropInfo) -> Bool {
        let m = minute(info)
        ghost = nil
        onDrop(m, info.itemProviders(for: [UTType.plainText]))
        return true
    }
}
