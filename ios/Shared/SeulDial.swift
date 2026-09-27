import SwiftUI

/// 24시간 도넛형 다이얼. 앱의 원형 뷰와 위젯이 같이 쓴다(위젯 호환을 위해 Canvas 대신 Shape만 사용).
struct DialItem: Identifiable {
    let id: UUID
    let start: Int
    let end: Int
    let color: HSB
    let faded: Bool
}

struct DialArc: Shape {
    var start: Double
    var end: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(start / 1440 * 360 - 90),
                 endAngle: .degrees(end / 1440 * 360 - 90),
                 clockwise: false)
        return p
    }
}

struct DialHand: Shape {
    var minute: Double
    var innerFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let a = minute / 1440 * 2 * .pi - .pi / 2
        var p = Path()
        p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r * innerFraction, y: c.y + CGFloat(sin(a)) * r * innerFraction))
        p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r))
        return p
    }
}

struct DialTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        for h in 0..<24 {
            let a = Double(h) / 24 * 2 * .pi - .pi / 2
            let len: CGFloat = h % 6 == 0 ? r * 0.1 : r * 0.045
            p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r))
            p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - len), y: c.y + CGFloat(sin(a)) * (r - len)))
        }
        return p
    }
}

struct SeulDial: View {
    let items: [DialItem]
    let palette: SeulPalette
    var now: Date?
    var ringWidth: CGFloat
    var showCenter: Bool = true
    var showLabels: Bool = true

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ring
                arcs
                DialTicks()
                    .stroke(palette.inkFaint.color, lineWidth: 1)
                    .padding(ringWidth + size * 0.025)
                if showLabels {
                    labels(size: size)
                }
                if let now = now {
                    hand(now: now, size: size)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var ring: some View {
        Circle()
            .stroke(palette.surfaceAlt.color, lineWidth: ringWidth)
            .padding(ringWidth / 2)
    }

    private var arcs: some View {
        ZStack {
            ForEach(items) { item in
                arc(item)
            }
        }
    }

    private func arc(_ item: DialItem) -> some View {
        let color: Color = item.faded ? item.color.muted().color : item.color.color
        let start = Double(item.start)
        let end = Double(max(item.start + 2, item.end - 2))
        return DialArc(start: start, end: end)
            .stroke(color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
            .padding(ringWidth / 2)
    }

    @ViewBuilder
    private func hand(now: Date, size: CGFloat) -> some View {
        let minute = Double(Day.minuteOfDay(now))
        let lineWidth: CGFloat = max(1.5, size * 0.008)
        DialHand(minute: minute, innerFraction: showCenter ? 0.5 : 0.12)
            .stroke(palette.accent.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        if showCenter {
            VStack(spacing: size * 0.01) {
                Text(Day.hhmm(Day.minuteOfDay(now)))
                    .font(SeulFont.title(size * 0.13))
                    .foregroundColor(palette.ink.color)
                Text("지금")
                    .font(SeulFont.mono(max(9, size * 0.04)))
                    .foregroundColor(palette.accent.color)
            }
        } else {
            Circle()
                .fill(palette.accent.color)
                .frame(width: size * 0.06, height: size * 0.06)
        }
    }

    private func labels(size: CGFloat) -> some View {
        ZStack {
            ForEach([0, 6, 12, 18], id: \.self) { h in
                label(hour: h, size: size)
            }
        }
        .frame(width: size, height: size)
    }

    private func label(hour h: Int, size: CGFloat) -> some View {
        let r: CGFloat = size / 2 - ringWidth - size * 0.12
        let a: Double = Double(h) / 24 * 2 * .pi - .pi / 2
        let x: CGFloat = size / 2 + CGFloat(cos(a)) * r
        let y: CGFloat = size / 2 + CGFloat(sin(a)) * r
        return Text("\(h)")
            .font(SeulFont.mono(max(8, size * 0.04)))
            .foregroundColor(palette.inkSoft.color)
            .position(x: x, y: y)
    }
}

extension AppData {
    func dialItems(on key: String, palette: SeulPalette, now: Date = Date()) -> [DialItem] {
        let todayKey = Day.key(now)
        let nowMin = Day.minuteOfDay(now)
        return effectiveBlocks(on: key, todayKey: todayKey).map { b in
            let past = key < todayKey || (key == todayKey && b.endMinute <= nowMin)
            return DialItem(id: b.id, start: b.startMinute, end: b.endMinute,
                            color: palette.swatch(for: b.taskId),
                            faded: b.state == .missed || (past && b.state != .logged))
        }
    }
}
