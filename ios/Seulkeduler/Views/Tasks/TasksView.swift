import SwiftUI

/// 할 일 탭: 프로젝트별 아코디언 + 완료됨 섹션.
struct TasksView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c

    @State private var collapsed: Set<String> = []
    @State private var showCompleted = false
    @State private var formMode: TaskFormView.Mode?
    @State private var projectAlert: ProjectAlert?
    @State private var projectName = ""

    enum ProjectAlert: Identifiable {
        case add
        case rename(Project)
        var id: String {
            switch self {
            case .add: return "add"
            case .rename(let p): return p.id.uuidString
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(store.activeTaskGroups, id: \.project?.id) { group in
                    accordion(project: group.project, tasks: group.tasks)
                }
                completedSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .fullScreenCover(item: $formMode) { mode in
            TaskFormView(mode: mode)
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
        .alert(projectAlertTitle, isPresented: Binding(get: { projectAlert != nil }, set: { if !$0 { projectAlert = nil } })) {
            TextField("프로젝트 이름", text: $projectName)
            Button("취소", role: .cancel) { projectAlert = nil }
            Button("저장") {
                let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                switch projectAlert {
                case .add: store.addProject(name: name)
                case .rename(let p): store.renameProject(p.id, name: name)
                case .none: break
                }
                projectAlert = nil
            }
        }
    }

    private var projectAlertTitle: String {
        if case .rename = projectAlert { return "프로젝트 이름 변경" }
        return "새 프로젝트"
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("할 일")
                .font(SeulFont.title(30))
                .foregroundColor(c.ink.color)
            Spacer()
            Chip(title: "프로젝트", symbol: "folder.badge.plus") {
                projectName = ""
                projectAlert = .add
            }
            IconButton(symbol: "plus", filled: true, label: "할 일 추가") { formMode = .new(projectId: nil) }
        }
    }

    private func key(_ p: Project?) -> String { p?.id.uuidString ?? "none" }

    private func accordion(project: Project?, tasks: [TaskItem]) -> some View {
        let isOpen = !collapsed.contains(key(project))
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isOpen { collapsed.insert(key(project)) } else { collapsed.remove(key(project)) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .foregroundColor(c.inkSoft.color)
                    Text(project?.name ?? "미분류")
                        .font(SeulFont.medium(17))
                        .foregroundColor(c.ink.color)
                    Text("\(tasks.count)")
                        .font(SeulFont.mono(12))
                        .foregroundColor(c.inkSoft.color)
                    Spacer()
                    if let p = project {
                        Menu {
                            Button { formMode = .new(projectId: p.id) } label: { Label("할 일 추가", systemImage: "plus") }
                            Button {
                                projectName = p.name
                                projectAlert = .rename(p)
                            } label: { Label("이름 변경", systemImage: "pencil") }
                            Button(role: .destructive) {
                                store.dialog = DialogConfig(title: "‘\(p.name)’ 프로젝트를 삭제할까요?",
                                                            message: "안의 할 일은 지워지지 않고 ‘미분류’로 옮겨져요.",
                                                            confirmTitle: "삭제", destructive: true) {
                                    store.haptic(.warning)
                                    store.deleteProject(p.id)
                                }
                            } label: { Label("삭제", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(c.inkSoft.color)
                                .frame(width: Touch.min, height: Touch.min)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .frame(minHeight: Touch.min)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                if tasks.isEmpty {
                    Button { formMode = .new(projectId: project?.id) } label: {
                        Text("+ 할 일 추가")
                            .font(SeulFont.body(14))
                            .foregroundColor(c.inkSoft.color)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .strokeBorder(c.line.color, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    ForEach(tasks) { t in
                        Button { formMode = .edit(t.id) } label: { TaskCard(task: t) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private var completedSection: some View {
        let done = store.finishedTasks
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCompleted.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .rotationEffect(.degrees(showCompleted ? 90 : 0))
                        .foregroundColor(c.inkSoft.color)
                    Text("완료됨")
                        .font(SeulFont.medium(17))
                        .foregroundColor(c.inkSoft.color)
                    Text("\(done.count)")
                        .font(SeulFont.mono(12))
                        .foregroundColor(c.inkFaint.color)
                    Spacer()
                }
                .frame(minHeight: Touch.min)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showCompleted {
                ForEach(done) { t in
                    Button { formMode = .edit(t.id) } label: { TaskCard(task: t) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.top, 10)
    }
}
