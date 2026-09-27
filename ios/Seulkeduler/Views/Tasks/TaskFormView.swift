import SwiftUI

/// 할 일 추가/수정 전체 화면 폼. 수정 모드에서는 진행 현황과 최근 리뷰 목록(상세뷰)도 함께 보여준다.
struct TaskFormView: View {
    enum Mode: Identifiable {
        case new(projectId: UUID?)
        case edit(UUID)

        var id: String {
            switch self {
            case .new(let p): return "new-\(p?.uuidString ?? "none")"
            case .edit(let id): return id.uuidString
            }
        }
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var onSaved: ((TaskItem) -> Void)?

    @State private var draft: TaskItem
    @State private var unlimited: Bool
    @State private var targetValue: Int
    @State private var confirmDelete = false
    @State private var showAppPicker = false
    @State private var showNewProject = false
    @State private var newProjectName = ""
    @State private var loaded = false

    init(mode: Mode, onSaved: ((TaskItem) -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        var pid: UUID?
        if case .new(let p) = mode { pid = p }
        _draft = State(initialValue: TaskItem(title: "", projectId: pid))
        _unlimited = State(initialValue: false)
        _targetValue = State(initialValue: 10)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    titleField
                    projectPicker
                    typePicker
                    importancePicker
                    memoField
                    linkField
                    appLink
                    if isEditing, let saved = store.task(draft.id) {
                        detailSections(saved)
                    }
                    PrimaryButton(title: isEditing ? "저장" : "추가", action: save)
                        .opacity(canSave ? 1 : 0.4)
                        .disabled(!canSave)
                        .padding(.top, 4)
                    if isEditing { deleteButton }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(c.bg.color.ignoresSafeArea())
        .onAppear(perform: load)
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(selected: $draft.linkedApp)
                .environment(\.seul, store.palette)
        }
        .alert("새 프로젝트", isPresented: $showNewProject) {
            TextField("프로젝트 이름", text: $newProjectName)
            Button("취소", role: .cancel) {}
            Button("추가") {
                let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                draft.projectId = store.addProject(name: name).id
            }
        }
    }

    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if case .edit(let id) = mode, let t = store.task(id) {
            draft = t
            unlimited = t.type == .recurring && t.target == nil
            targetValue = t.target ?? 10
        }
    }

    private func save() {
        guard canSave else { return }
        var t = draft
        t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.target = t.type == .recurring ? (unlimited ? nil : max(1, targetValue)) : nil
        store.upsertTask(t)
        dismiss()
        onSaved?(t)
    }

    // MARK: 섹션

    private var topBar: some View {
        HStack {
            IconButton(symbol: "xmark", label: "닫기") { dismiss() }
            Spacer()
            Text(isEditing ? "할 일 수정" : "새 할 일")
                .font(SeulFont.title(19))
                .foregroundColor(c.ink.color)
            Spacer()
            Button(isEditing ? "저장" : "추가", action: save)
                .font(SeulFont.medium(16))
                .foregroundColor(canSave ? c.accent.color : c.inkFaint.color)
                .disabled(!canSave)
                .frame(minWidth: Touch.min, minHeight: Touch.min)
                .padding(.trailing, 6)
                .accessibilityIdentifier("form-save-top")
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "제목")
            TextField("무엇을 할까요?", text: $draft.title)
                .font(SeulFont.medium(20))
                .foregroundColor(c.ink.color)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surface.color))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(c.line.color, lineWidth: 1))
        }
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "프로젝트")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "미분류", selected: draft.projectId == nil) { draft.projectId = nil }
                    ForEach(store.sortedProjects) { p in
                        Chip(title: p.name, selected: draft.projectId == p.id) { draft.projectId = p.id }
                    }
                    Chip(title: "새 프로젝트", symbol: "plus") {
                        newProjectName = ""
                        showNewProject = true
                    }
                }
            }
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "타입")
            HStack(spacing: 8) {
                Chip(title: "한 번", selected: draft.type == .once) { draft.type = .once }
                Chip(title: "반복", symbol: "repeat", selected: draft.type == .recurring) { draft.type = .recurring }
            }
            if draft.type == .recurring {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("빈도").font(SeulFont.mono(11)).foregroundColor(c.inkSoft.color)
                        HStack(spacing: 8) {
                            ForEach(Frequency.allCases) { f in
                                Chip(title: f.label, selected: draft.frequency == f) { draft.frequency = f }
                            }
                        }
                        Divider()
                        Text("목표 횟수 (완료해야 하는 횟수)").font(SeulFont.mono(11)).foregroundColor(c.inkSoft.color)
                        HStack {
                            Chip(title: "무제한", selected: unlimited) { unlimited.toggle() }
                            Spacer()
                            if !unlimited {
                                IconButton(symbol: "minus", label: "목표 줄이기") { targetValue = max(1, targetValue - 1) }
                                Text("\(targetValue)회")
                                    .font(SeulFont.monoMedium(17))
                                    .foregroundColor(c.ink.color)
                                    .frame(minWidth: 52)
                                IconButton(symbol: "plus", label: "목표 늘리기") { targetValue = min(999, targetValue + 1) }
                            }
                        }
                        Text("못한 회차는 횟수에 들어가지 않고, 완료 횟수가 목표에 닿으면 자동으로 끝나요.")
                            .font(SeulFont.body(12))
                            .foregroundColor(c.inkFaint.color)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var importancePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "중요도")
            HStack {
                StarsView(value: draft.importance, size: 22) { draft.importance = $0 }
                    .padding(.leading, -10)
                Spacer()
            }
            Text(importanceHint)
                .font(SeulFont.body(12))
                .foregroundColor(c.inkFaint.color)
        }
    }

    private var importanceHint: String {
        switch draft.importance {
        case 5: return "알림: 30분 전 · 10분 전 · 시작 시"
        case 4: return "알림: 10분 전 · 시작 시"
        case 3: return "알림: 시작 시"
        default: return "알림 없음"
        }
    }

    private var memoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "메모")
            TextField("메모", text: $draft.memo, axis: .vertical)
                .lineLimit(3...8)
                .font(SeulFont.body(15))
                .foregroundColor(c.ink.color)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surface.color))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(c.line.color, lineWidth: 1))
        }
    }

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "링크")
            TextField("https://", text: $draft.link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(SeulFont.mono(14))
                .foregroundColor(c.ink.color)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(c.surface.color))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(c.line.color, lineWidth: 1))
        }
    }

    private var appLink: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "연결 앱")
            if let app = LinkableApp.find(draft.linkedApp) {
                HStack(spacing: 0) {
                    Button { app.open() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: app.symbol)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(c.toneGradient(c.accent)))
                            Text(app.name).font(SeulFont.medium(14)).foregroundColor(c.ink.color)
                        }
                        .padding(.leading, 6)
                    }
                    .buttonStyle(.plain)
                    Button { draft.linkedApp = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(c.inkSoft.color)
                            .frame(width: Touch.min, height: Touch.min)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 40)
                .background(Capsule().fill(c.surfaceAlt.color))
                .padding(.vertical, 2)
            } else {
                Chip(title: "앱 연결", symbol: "app.badge") { showAppPicker = true }
            }
        }
    }

    private func detailSections(_ saved: TaskItem) -> some View {
        let reviews = store.reviews(for: saved.id)
        return VStack(alignment: .leading, spacing: 20) {
            if saved.type == .recurring {
                ProgressSummaryView(task: saved, reviews: reviews)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "최근 리뷰")
                if reviews.isEmpty {
                    Text("아직 체크인 기록이 없어요")
                        .font(SeulFont.body(14))
                        .foregroundColor(c.inkFaint.color)
                } else {
                    Card(padding: 4) {
                        VStack(spacing: 0) {
                            ForEach(Array(reviews.prefix(5).enumerated()), id: \.element.id) { i, r in
                                if i > 0 { Divider().padding(.horizontal, 12) }
                                ReviewRow(review: r, showDate: true).padding(12)
                            }
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        SecondaryButton(title: confirmDelete ? "정말 삭제?" : "삭제", destructive: true) {
            if confirmDelete {
                store.haptic(.warning)
                store.deleteTask(draft.id)
                dismiss()
            } else {
                withAnimation { confirmDelete = true }
            }
        }
        .padding(.top, 8)
    }
}

struct ReviewRow: View {
    @Environment(\.seul) private var c
    let review: CheckinReview
    let showDate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if showDate {
                    Text(Day.monthDayWeekday(review.date))
                        .font(SeulFont.mono(12))
                        .foregroundColor(c.inkSoft.color)
                }
                PillTag(text: review.completed ? "완료" : "못했어요", strong: review.completed)
                Text("\(review.occurrence)회차")
                    .font(SeulFont.mono(11))
                    .foregroundColor(c.inkFaint.color)
                Spacer()
            }
            if !review.memo.isEmpty {
                Text(review.memo)
                    .font(SeulFont.body(14))
                    .foregroundColor(c.ink.color)
            }
        }
    }
}
