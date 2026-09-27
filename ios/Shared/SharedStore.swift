import Foundation

/// 앱과 위젯이 함께 읽는 JSON 저장소. App Group 컨테이너가 없으면(서명 없는 빌드 등) Documents로 대체한다.
enum SharedStore {
    static let defaultAppGroup = "group.com.growv.seulkeduler"
    static let fileName = "seulkeduler.json"

    /// Sideloadly 같은 무료 서명 도구는 App Group ID를 바꿔서 서명할 수 있으므로,
    /// 설치된 프로비저닝 프로필에 실제로 들어 있는 그룹을 먼저 쓰고 없으면 기본값을 쓴다.
    static let appGroup: String = provisionedAppGroup() ?? defaultAppGroup

    private static func provisionedAppGroup() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let start = raw.range(of: Data("<?xml".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), in: start.lowerBound..<raw.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: raw.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else { return nil }
        return groups.first { !$0.contains("*") }
    }

    static var fileURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load() -> AppData? {
        guard let raw = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(AppData.self, from: raw)
    }

    static func save(_ data: AppData) {
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }
}
