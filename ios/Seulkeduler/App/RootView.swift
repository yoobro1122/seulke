import SwiftUI

enum AppTab: String, CaseIterable {
    case today, tasks, settings

    var title: String {
        switch self {
        case .today: return "오늘"
        case .tasks: return "할일"
        case .settings: return "설정"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .tasks: return "checklist"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var today: TodayState
    @Environment(\.seul) private var c
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today

    static let tabBarHeight: CGFloat = 64

    private let checkinTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let barHeight = Self.tabBarHeight + safeBottom
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + safeBottom

            ZStack(alignment: .bottom) {
                c.bg.color.ignoresSafeArea()

                content(barHeight: barHeight, peek: TodaySheet.peekContent + barHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if tab == .today {
                    TodaySheet(containerHeight: fullHeight, safeTop: geo.safeAreaInsets.top,
                               safeBottom: safeBottom, barHeight: barHeight)
                        .zIndex(today.sheet == .full ? 3 : 1)
                }

                SeulTabBar(tab: $tab, safeBottom: safeBottom)
                    .zIndex(2)
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                // 스크롤 내용이 상태바 뒤로 비치지 않도록 가림막
                Color.clear
                    .frame(height: 0)
                    .background(c.bg.color.ignoresSafeArea(edges: .top))
                    .allowsHitTesting(false)
            }
        }
        .overlay { overlays }
        .onAppear {
            store.pollCheckins()
            if store.settings.notificationsEnabled {
                NotificationService.shared.requestAuthorization { _ in
                    NotificationService.shared.scheduleRefresh(store.data)
                }
            }
        }
        .onReceive(checkinTimer) { _ in store.pollCheckins() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.pollCheckins() }
        }
        .onOpenURL { _ in
            tab = .today
            today.dateKey = Day.todayKey
        }
    }

    @ViewBuilder
    private func content(barHeight: CGFloat, peek: CGFloat) -> some View {
        switch tab {
        case .today:
            TodayView(bottomInset: peek)
        case .tasks:
            TasksView()
                .padding(.bottom, barHeight)
        case .settings:
            SettingsView()
                .padding(.bottom, barHeight)
        }
    }

    @ViewBuilder
    private var overlays: some View {
        ZStack {
            if let id = store.presentedCheckinId, let block = store.block(id), let task = store.task(block.taskId) {
                CheckinOverlay(block: block, task: task)
                    .id(id)
                    .transition(.opacity)
            } else if let tid = store.goalPromptTaskId, let task = store.task(tid) {
                GoalPromptOverlay(task: task)
                    .transition(.opacity)
            }
            if let dialog = store.dialog {
                DialogOverlay(config: dialog) { store.dialog = nil }
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.presentedCheckinId)
        .animation(.easeOut(duration: 0.2), value: store.goalPromptTaskId)
        .animation(.easeOut(duration: 0.18), value: store.dialog?.id)
    }
}

struct SeulTabBar: View {
    @Environment(\.seul) private var c
    @Binding var tab: AppTab
    let safeBottom: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { t in
                SeulTabItem(tab: t, selected: tab == t) { tab = t }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: tab)
        .padding(.horizontal, 16)
        .frame(height: RootView.tabBarHeight)
        .padding(.bottom, safeBottom)
        .frame(maxWidth: .infinity)
        .background(
            c.surface.color
                .overlay(Rectangle().fill(c.line.color).frame(height: 1), alignment: .top)
        )
    }
}

/// 하단 탭 한 칸. 활성 탭은 톤온톤 그라데이션 필.
struct SeulTabItem: View {
    @Environment(\.seul) private var c
    let tab: AppTab
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(.plain)
            .accessibilityLabel(tab.title)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var pill: AnyShapeStyle {
        selected ? AnyShapeStyle(c.accentGradient) : AnyShapeStyle(Color.clear)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.symbol)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            if selected {
                Text(tab.title).font(SeulFont.medium(14))
            }
        }
        .foregroundColor(selected ? Color.white : c.inkSoft.color)
        .padding(.horizontal, selected ? 18 : 12)
        .frame(height: 42)
        .background(Capsule().fill(pill))
        .frame(maxWidth: .infinity, minHeight: Touch.min)
        .contentShape(Rectangle())
    }
}
