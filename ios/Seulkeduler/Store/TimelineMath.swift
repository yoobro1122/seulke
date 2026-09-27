import Foundation

/// 타임라인 드래그 계산: 15분 그리드 스냅 + 20분 자석 스냅.
enum TimelineMath {
    static let grid = 15
    static let magnet = 20
    static let minDuration = 15
    static let dayMinutes = 1440

    static func snap(_ minute: Double) -> Int {
        Int((minute / Double(grid)).rounded()) * grid
    }

    /// 이동: 그리드에 스냅하되, 20분 이내에 다른 블록 가장자리가 있으면 거기에 딱 붙인다.
    static func proposeMove(rawStart: Double, duration: Int, others: [ScheduleBlock]) -> Int {
        var start = snap(rawStart)
        var best = Double(magnet) + 0.001
        let rawEnd = rawStart + Double(duration)
        for o in others {
            let d1 = abs(rawStart - Double(o.endMinute))
            if d1 < best { best = d1; start = o.endMinute }
            let d2 = abs(rawEnd - Double(o.startMinute))
            if d2 < best { best = d2; start = o.startMinute - duration }
        }
        return min(max(start, 0), dayMinutes - duration)
    }

    /// 리사이즈(하단 그립): 끝 시각을 스냅, 20분 이내의 다음 블록 시작에 자석.
    static func proposeResizeEnd(rawEnd: Double, start: Int, others: [ScheduleBlock]) -> Int {
        var end = snap(rawEnd)
        var best = Double(magnet) + 0.001
        for o in others where o.startMinute > start {
            let d = abs(rawEnd - Double(o.startMinute))
            if d < best { best = d; end = o.startMinute }
        }
        return min(max(end, start + minDuration), dayMinutes)
    }
}
