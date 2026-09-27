import SwiftUI

enum ThemeEditorTarget: Identifiable {
    case new
    case edit(CustomColorTheme)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let t): return t.id.uuidString
        }
    }
}

/// 커스텀 테마 생성/수정: hue 슬라이더 하나로 전체 팔레트 유도, 스와치 7칸 중 원하는 칸만 개별 hue로 오버라이드.
struct ThemeEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let target: ThemeEditorTarget

    @State private var theme: CustomColorTheme
    @State private var selectedSwatch: Int?
    @State private var confirmDelete = false

    init(target: ThemeEditorTarget) {
        self.target = target
        switch target {
        case .new: _theme = State(initialValue: CustomColorTheme(baseHue: Double(Int.random(in: 0..<360))))
        case .edit(let t): _theme = State(initialValue: t)
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    var body: some View {
        let p = ThemeCatalog.palette(for: theme)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(isEditing ? "테마 편집" : "새 테마")
                        .font(SeulFont.title(24))
                        .foregroundColor(p.ink.color)
                    Spacer()
                }

                preview(p)

                VStack(alignment: .leading, spacing: 8) {
                    label("기본 색상", p)
                    HueSlider(hue: $theme.baseHue)
                }

                VStack(alignment: .leading, spacing: 10) {
                    label("스와치 (눌러서 개별 색상 지정)", p)
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { i in
                            Button { selectedSwatch = selectedSwatch == i ? nil : i } label: {
                                Circle()
                                    .fill(p.toneGradient(p.swatches[i]))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(selectedSwatch == i ? p.ink.color : Color.clear, lineWidth: 2).padding(-3))
                                    .overlay(alignment: .topTrailing) {
                                        if theme.presetHueOverrides[i] != nil {
                                            Circle().fill(p.ink.color).frame(width: 7, height: 7)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: Touch.min)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let i = selectedSwatch {
                        HueSlider(hue: Binding(
                            get: { theme.presetHueOverrides[i] ?? (theme.baseHue + ThemeCatalog.swatchOffsets[i]).truncatingRemainder(dividingBy: 360) },
                            set: { theme.presetHueOverrides[i] = ($0 + 360).truncatingRemainder(dividingBy: 360) }
                        ))
                        if theme.presetHueOverrides[i] != nil {
                            Chip(title: "기본값으로", symbol: "arrow.uturn.backward") { theme.presetHueOverrides[i] = nil }
                        }
                    }
                }

                PrimaryButton(title: "저장하고 적용", tint: p.accent) {
                    store.saveCustomTheme(theme)
                    dismiss()
                }

                if isEditing {
                    SecondaryButton(title: confirmDelete ? "정말 삭제?" : "테마 삭제", destructive: true) {
                        if confirmDelete {
                            store.haptic(.warning)
                            store.deleteCustomTheme(theme.id)
                            dismiss()
                        } else {
                            withAnimation { confirmDelete = true }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(p.bg.color.ignoresSafeArea())
        .environment(\.seul, p)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func label(_ text: String, _ p: SeulPalette) -> some View {
        Text(text).font(SeulFont.mono(11)).foregroundColor(p.inkSoft.color)
    }

    private func preview(_ p: SeulPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 10) {
                    Text(Day.hhmm(540 + i * 60))
                        .font(SeulFont.mono(10))
                        .foregroundColor(p.inkFaint.color)
                        .frame(width: 38, alignment: .trailing)
                    RoundedRectangle(cornerRadius: Radius.scheduleBlock, style: .continuous)
                        .fill(p.toneGradient(p.swatches[[0, 3, 5][i]]))
                        .frame(height: 40)
                        .overlay(alignment: .leading) {
                            Text(["아침 운동", "집중 작업", "독서"][i])
                                .font(SeulFont.medium(13))
                                .foregroundColor(.white)
                                .padding(.leading, 12)
                        }
                }
            }
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "sun.max").font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("오늘").font(SeulFont.medium(13))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Capsule().fill(p.accentGradient))
                Image(systemName: "checklist").foregroundColor(p.inkSoft.color).frame(width: 60)
                Image(systemName: "gearshape").foregroundColor(p.inkSoft.color).frame(width: 60)
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(p.surface.color))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).stroke(p.line.color, lineWidth: 1))
    }
}

/// 무지개 트랙 위의 hue 슬라이더(0~360)
struct HueSlider: View {
    @Binding var hue: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = CGFloat(hue / 360) * w
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
                        Color(hue: $0, saturation: 0.55, brightness: 0.85)
                    }, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 14)
                Circle()
                    .fill(Color(hue: hue / 360, saturation: 0.55, brightness: 0.85))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .offset(x: min(max(x - 14, -4), w - 24))
            }
            .frame(height: Touch.min)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                hue = Double(min(max(v.location.x / w, 0), 1)) * 359.9
            })
        }
        .frame(height: Touch.min)
    }
}
