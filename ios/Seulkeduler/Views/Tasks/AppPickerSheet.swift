import SwiftUI

/// 연결 앱 선택. iOS는 설치 앱 목록을 조회할 수 없어서, 미리 등록된 URL 스킴 중 canOpenURL로 확인된 앱만 고를 수 있다.
struct AppPickerSheet: View {
    @Environment(\.seul) private var c
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String?

    var body: some View {
        let installed = LinkableApp.all.filter(\.isInstalled)
        let missing = LinkableApp.all.filter { !$0.isInstalled }

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("앱 연결")
                        .font(SeulFont.title(24))
                        .foregroundColor(c.ink.color)
                    Text("iOS는 설치된 앱 전체 목록을 볼 수 없어서, 지원하는 앱 중 이 기기에 설치된 앱만 연결할 수 있어요.")
                        .font(SeulFont.body(13))
                        .foregroundColor(c.inkSoft.color)
                }

                SectionLabel(text: "설치됨")
                if installed.isEmpty {
                    Text("연결 가능한 앱이 없어요")
                        .font(SeulFont.body(14))
                        .foregroundColor(c.inkFaint.color)
                }
                grid(installed, enabled: true)

                if !missing.isEmpty {
                    SectionLabel(text: "설치 안 됨").padding(.top, 8)
                    grid(missing, enabled: false)
                }
            }
            .padding(22)
        }
        .background(c.bg.color.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func grid(_ apps: [LinkableApp], enabled: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
            ForEach(apps) { app in
                Button {
                    selected = app.id
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: app.symbol)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(enabled ? .white : c.inkFaint.color)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .fill(enabled ? AnyShapeStyle(c.toneGradient(c.accent)) : AnyShapeStyle(c.surfaceAlt.color)))
                            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .stroke(selected == app.id ? c.ink.color : Color.clear, lineWidth: 2))
                        Text(app.name)
                            .font(SeulFont.body(11))
                            .foregroundColor(enabled ? c.ink.color : c.inkFaint.color)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .disabled(!enabled)
            }
        }
    }
}
