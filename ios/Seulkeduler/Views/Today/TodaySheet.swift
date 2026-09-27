import SwiftUI

/// 오늘 탭 3단계 바텀시트(peek/half/full). full이면 하단 탭바를 덮는다.
/// 미완료 할 일 카드를 길게 눌러 타임라인 빈 곳에 끌어다 놓으면 30분 블록이 생긴다.
struct TodaySheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var today: TodayState
    @Environment(\.seul) private var c

    let containerHeight: CGFloat
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let barHeight: CGFloat

    /// peek 상태에서 탭바 위로 보이는 높이
    static let peekContent: CGFloat = 92

    @GestureState private var dragDelta: CGFloat = 0
    @State private var editing: TaskItem?

    private func height(_ d: TodayState.SheetDetent) -> CGFloat {
        switch d {
        case .peek: return Self.peekContent + barHeight
        case .half: return containerHeight * 0.52
        case .full: return containerHeight - safeTop - 8
        }
    }

    var body: some View {
        let base = height(today.sheet)
        let h = min(max(base - dragDelta, height(.peek) - 30), height(.full) + 20)

        VStack(spacing: 0) {
            handle
            ScrollView(showsIndicators: false) {
                cards
                    .padding(.horizontal, 16)
                    .padding(.bottom, (today.sheet == .full ? safeBottom : barHeight) + 16)
            }
            .disabled(today.sheet == .peek)
        }
        .frame(height: h, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            TopRoundedShape(radius: Radius.large)
                .fill(c.surface.color)
                .shadow(color: .black.opacity(0.1), radius: 16, y: -2)
        )
        .clipShape(TopRoundedShape(radius: Radius.large))
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: today.sheet)
        .fullScreenCover(item: $editing) { t in
            TaskFormView(mode: .edit(t.id))
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
    }

    private var handle: some View {
        VStack(spacing: 10) {
            Capsule().fill(c.line.color).frame(width: 40, height: 5).padding(.top, 8)
            HStack(alignment: .firstTextBaseline) {
                Text("할 일")
                    .font(SeulFont.title(20))
                    .foregroundColor(c.ink.color)
                Text("\(store.activeTasks.count)")
                    .font(SeulFont.mono(12))
                    .foregroundColor(c.inkSoft.color)
                Spacer()
                Text("길게 눌러 타임라인에 놓기")
                    .font(SeulFont.mono(10))
                    .foregroundColor(c.inkFaint.color)
                Button {
                    today.sheet = today.sheet == .peek ? .half : (today.sheet == .half ? .full : .peek)
                } label: {
                    Image(systemName: today.sheet == .full ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(c.inkSoft.color)
                        .frame(width: Touch.min, height: Touch.min)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(today.sheet == .full ? "시트 접기" : "시트 펼치기")
                .accessibilityIdentifier("sheet-toggle")
            }
            .padding(.leading, 20)
            .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .updating($dragDelta) { v, state, _ in state = v.translation.height }
                .onEnded { v in
                    let projected = height(today.sheet) - v.predictedEndTranslation.height
                    let options: [TodayState.SheetDetent] = [.peek, .half, .full]
                    today.sheet = options.min { abs(height($0) - projected) < abs(height($1) - projected) } ?? .peek
                }
        )
    }

    @ViewBuilder
    private var cards: some View {
        let groups = store.activeTaskGroups.filter { !$0.tasks.isEmpty }
        if groups.isEmpty {
            Text("할 일 탭에서 할 일을 추가하면 여기서 타임라인으로 끌어다 놓을 수 있어요.")
                .font(SeulFont.body(14))
                .foregroundColor(c.inkSoft.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(groups, id: \.project?.id) { group in
                    SectionLabel(text: group.project?.name ?? "미분류")
                        .padding(.top, 10)
                    ForEach(group.tasks) { t in
                        TaskCard(task: t)
                            .onTapGesture { editing = t }
                            .onDrag {
                                today.draggingTaskId = t.id
                                today.sheet = .peek
                                return NSItemProvider(object: t.id.uuidString as NSString)
                            }
                    }
                }
            }
        }
    }
}
