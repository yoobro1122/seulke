import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.seul) private var c

    @State private var editingTheme: ThemeEditorTarget?
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDoc = BackupDocument(data: Data())
    @State private var resetArmed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("설정")
                    .font(SeulFont.title(30))
                    .foregroundColor(c.ink.color)

                section("화면") {
                    row("오늘 탭 기본 화면", caption: "앱을 시작할 때 한 번 적용돼요") {
                        segmented(["목록", "원형"], selected: store.settings.todayDefaultView == .list ? 0 : 1) { i in
                            store.updateSettings { $0.todayDefaultView = i == 0 ? .list : .dial }
                        }
                    }
                    Divider()
                    row("주 시작 요일") {
                        segmented(["일", "월"], selected: store.settings.weekStart == 1 ? 0 : 1) { i in
                            store.updateSettings { $0.weekStart = i == 0 ? 1 : 2 }
                        }
                    }
                }

                section("알림 · 햅틱") {
                    row("일정 시작 알림", caption: "중요도 별 3개 이상인 일정에 알림") {
                        Toggle("", isOn: Binding(get: { store.settings.notificationsEnabled }, set: setNotifications))
                            .labelsHidden()
                            .tint(c.accent.color)
                    }
                    Divider()
                    row("햅틱") {
                        Toggle("", isOn: Binding(get: { store.settings.hapticsEnabled },
                                                 set: { v in store.updateSettings { $0.hapticsEnabled = v } }))
                            .labelsHidden()
                            .tint(c.accent.color)
                    }
                }

                themeSection

                section("데이터") {
                    actionRow("백업 내보내기", symbol: "square.and.arrow.up") {
                        exportDoc = BackupDocument(data: store.exportJSON())
                        exporting = true
                    }
                    Divider()
                    actionRow("백업에서 복원", symbol: "square.and.arrow.down") { importing = true }
                    Divider()
                    actionRow(resetArmed ? "정말 초기화할까요? 한 번 더 누르기" : "데이터 초기화",
                              symbol: "trash", destructive: true) {
                        if resetArmed {
                            store.haptic(.warning)
                            store.resetData()
                            resetArmed = false
                        } else {
                            withAnimation { resetArmed = true }
                        }
                    }
                }

                Text("슬케줄러 iOS \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")\n로그인 없이 이 기기에만 저장돼요.")
                    .font(SeulFont.mono(11))
                    .foregroundColor(c.inkFaint.color)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .sheet(item: $editingTheme) { target in
            ThemeEditorSheet(target: target)
                .environmentObject(store)
                .environment(\.seul, store.palette)
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: "seulkeduler-backup-\(Day.todayKey)") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let raw = try? Data(contentsOf: url) else { return }
            store.dialog = DialogConfig(title: "백업에서 복원할까요?",
                                        message: "지금 기기의 데이터는 백업 내용으로 완전히 바뀌어요.",
                                        confirmTitle: "복원", destructive: true) {
                do {
                    try store.importJSON(raw)
                    store.haptic(.success)
                } catch {
                    store.dialog = DialogConfig(title: "복원하지 못했어요",
                                                message: "슬케줄러 백업 파일이 맞는지 확인해 주세요.",
                                                cancelTitle: nil) {}
                }
            }
        }
    }

    private func setNotifications(_ on: Bool) {
        store.updateSettings { $0.notificationsEnabled = on }
        guard on else { return }
        NotificationService.shared.requestAuthorization { granted in
            if !granted {
                store.dialog = DialogConfig(title: "알림 권한이 꺼져 있어요",
                                            message: "iOS 설정 > 슬케줄러에서 알림을 허용해 주세요.",
                                            confirmTitle: "설정 열기") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
            }
        }
    }

    // MARK: 테마

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "색상 테마")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                themeCard(id: ThemeIds.mono, palette: ThemeCatalog.mono, custom: nil)
                ForEach(store.data.customThemes) { t in
                    themeCard(id: t.id.uuidString, palette: ThemeCatalog.palette(for: t), custom: t)
                }
                Button { editingTheme = .new } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text("새 테마").font(SeulFont.body(12))
                    }
                    .foregroundColor(c.inkSoft.color)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(c.line.color, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
            Text("길게 누르거나 선택된 테마를 다시 누르면 편집할 수 있어요.")
                .font(SeulFont.mono(10))
                .foregroundColor(c.inkFaint.color)
        }
    }

    /// 테마 이름은 표시하지 않고 스와치 미리보기로만 고른다.
    private func themeCard(id: String, palette p: SeulPalette, custom: CustomColorTheme?) -> some View {
        let selected = store.settings.colorTheme == id
        return Button {
            if selected, let t = custom {
                editingTheme = .edit(t)
            } else {
                store.selectTheme(id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Circle().fill(p.toneGradient(p.swatches[i])).frame(width: 14, height: 14)
                    }
                }
                HStack(spacing: 6) {
                    Capsule().fill(p.accentGradient).frame(width: 44, height: 14)
                    Capsule().fill(p.inkFaint.color).frame(width: 22, height: 6)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(p.accent.color)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(p.bg.color))
            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(selected ? p.accent.color : c.line.color, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            if let t = custom { editingTheme = .edit(t) }
        })
    }

    // MARK: 레이아웃 조각

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            Card(padding: 4) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func row<Trailing: View>(_ title: String, caption: String? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(SeulFont.medium(15)).foregroundColor(c.ink.color)
                if let caption = caption {
                    Text(caption).font(SeulFont.body(12)).foregroundColor(c.inkFaint.color)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
    }

    private func actionRow(_ title: String, symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(width: 22)
                Text(title).font(SeulFont.medium(15))
                Spacer()
            }
            .foregroundColor(destructive ? Color.red.opacity(0.8) : c.ink.color)
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func segmented(_ labels: [String], selected: Int, onSelect: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            ForEach(labels.indices, id: \.self) { i in
                Button { onSelect(i) } label: {
                    Text(labels[i])
                        .font(SeulFont.medium(13))
                        .foregroundColor(i == selected ? .white : c.inkSoft.color)
                        .frame(minWidth: 44, minHeight: 34)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(i == selected ? AnyShapeStyle(c.accentGradient) : AnyShapeStyle(Color.clear)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(c.surfaceAlt.color))
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
