import SwiftUI

/// HSB 색. 톤온톤 그라데이션처럼 테마 색에서 매번 계산되는 변형을 만들기 위해 원시값을 들고 다닌다.
struct HSB: Hashable {
    var h: Double
    var s: Double
    var b: Double

    var color: Color { Color(hue: h, saturation: s, brightness: b) }

    /// 같은 색상의 밝은 변형(그라데이션 윗단)
    func lighter(_ t: Double = 0.35) -> HSB {
        HSB(h: h, s: s * (1 - t * 0.6), b: min(1, b + (1 - b) * t))
    }

    /// 채도를 빼고 밝기를 중간으로 끌어온 톤다운 변형(지난/못한 일정)
    func muted(_ t: Double = 0.6) -> HSB {
        HSB(h: h, s: s * (1 - t), b: b + (0.8 - b) * t)
    }
}

struct SeulPalette {
    var bg: HSB
    var surface: HSB
    var surfaceAlt: HSB
    var ink: HSB
    var inkSoft: HSB
    var inkFaint: HSB
    var line: HSB
    var accent: HSB
    var swatches: [HSB]

    func swatch(for taskId: UUID) -> HSB {
        swatches[ThemeCatalog.swatchIndex(for: taskId)]
    }

    /// 톤온톤 그라데이션: 위는 밝은 변형, 아래는 원색.
    func toneGradient(_ base: HSB) -> LinearGradient {
        LinearGradient(colors: [base.lighter(0.3).color, base.color], startPoint: .top, endPoint: .bottom)
    }

    var accentGradient: LinearGradient { toneGradient(accent) }
}

/// hue 하나로 bg/ink/accent/스와치를 전부 유도하는 paletteForHue 이식.
enum ThemeCatalog {
    static let swatchOffsets: [Double] = [0, -18, 18, -36, 36, -54, 54]
    static let swatchBrightness: [Double] = [0.56, 0.62, 0.50, 0.66, 0.58, 0.52, 0.68]
    static let monoBrightness: [Double] = [0.22, 0.34, 0.44, 0.54, 0.29, 0.39, 0.49]

    /// 내장 테마 중 모노톤 화이트를 제외한 3개(딥퍼플/타이탄/포레스트 그린)는 편집·삭제 가능한 테마로 시드한다.
    static func seedThemes() -> [CustomColorTheme] {
        [CustomColorTheme(baseHue: 268, saturation: 1.0),
         CustomColorTheme(baseHue: 212, saturation: 0.32),
         CustomColorTheme(baseHue: 148, saturation: 0.8)]
    }

    static var mono: SeulPalette { palette(baseHue: nil, saturation: 0, overrides: []) }

    static func palette(themeId: String, customs: [CustomColorTheme]) -> SeulPalette {
        if let t = customs.first(where: { $0.id.uuidString == themeId }) {
            return palette(for: t)
        }
        return mono
    }

    static func palette(for t: CustomColorTheme) -> SeulPalette {
        palette(baseHue: t.baseHue, saturation: t.saturation, overrides: t.presetHueOverrides)
    }

    static func palette(baseHue: Double?, saturation: Double, overrides: [Double?]) -> SeulPalette {
        let isMono = baseHue == nil
        let k = isMono ? 0 : max(0, min(saturation, 1.2))
        let h = (baseHue ?? 0) / 360
        func wrap(_ x: Double) -> Double { let v = x.truncatingRemainder(dividingBy: 1); return v < 0 ? v + 1 : v }

        var swatches: [HSB] = []
        for i in 0..<7 {
            let override = i < overrides.count ? overrides[i] : nil
            if let o = override {
                swatches.append(HSB(h: o / 360, s: max(0.45, 0.5 * k), b: swatchBrightness[i]))
            } else if isMono {
                swatches.append(HSB(h: 0, s: 0, b: monoBrightness[i]))
            } else {
                swatches.append(HSB(h: wrap(h + swatchOffsets[i] / 360), s: 0.5 * k, b: swatchBrightness[i]))
            }
        }

        return SeulPalette(
            bg: HSB(h: h, s: 0.05 * k, b: 0.975),
            surface: HSB(h: h, s: 0.02 * k, b: 1.0),
            surfaceAlt: HSB(h: h, s: 0.08 * k, b: 0.94),
            ink: HSB(h: h, s: 0.45 * k, b: 0.16),
            inkSoft: HSB(h: h, s: 0.22 * k, b: 0.42),
            inkFaint: HSB(h: h, s: 0.10 * k, b: 0.68),
            line: HSB(h: h, s: 0.08 * k, b: 0.89),
            accent: isMono ? HSB(h: 0, s: 0, b: 0.16) : HSB(h: h, s: 0.6 * k, b: 0.5),
            swatches: swatches
        )
    }

    /// 할 일 ID 해시로 스와치 하나를 고정 배정(앱 재시작해도 동일해야 하므로 FNV-1a 사용).
    static func swatchIndex(for id: UUID) -> Int {
        var hash: UInt32 = 2_166_136_261
        for byte in id.uuidString.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash % 7)
    }
}

enum SeulFont {
    static func title(_ size: CGFloat) -> Font { .custom("PlayfairDisplay-SemiBold", size: size) }
    static func body(_ size: CGFloat = 15) -> Font { .custom("Inter-Regular", size: size) }
    static func medium(_ size: CGFloat = 15) -> Font { .custom("Inter-Medium", size: size) }
    static func mono(_ size: CGFloat = 11) -> Font { .custom("IBMPlexMono-Regular", size: size) }
    static func monoMedium(_ size: CGFloat = 11) -> Font { .custom("IBMPlexMono-Medium", size: size) }
}
