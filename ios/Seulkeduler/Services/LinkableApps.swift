import UIKit

/// 할 일 ↔ 앱 연결의 iOS 대안.
/// iOS는 설치된 앱 목록을 조회할 수 없으므로, URL 스킴을 미리 등록해 둔 앱 목록 중
/// canOpenURL로 설치가 확인되는 앱만 고를 수 있게 한다(스킴은 Info.plist LSApplicationQueriesSchemes에도 등록).
struct LinkableApp: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let url: String

    var scheme: String { String(url.prefix { $0 != ":" }) }

    var isInstalled: Bool {
        guard let u = URL(string: url) else { return false }
        return UIApplication.shared.canOpenURL(u)
    }

    func open() {
        guard let u = URL(string: url) else { return }
        UIApplication.shared.open(u)
    }

    static let all: [LinkableApp] = [
        LinkableApp(id: "kakaotalk", name: "카카오톡", symbol: "message.fill", url: "kakaotalk://"),
        LinkableApp(id: "youtube", name: "YouTube", symbol: "play.rectangle.fill", url: "youtube://"),
        LinkableApp(id: "instagram", name: "Instagram", symbol: "camera.fill", url: "instagram://"),
        LinkableApp(id: "notion", name: "Notion", symbol: "doc.text.fill", url: "notion://"),
        LinkableApp(id: "slack", name: "Slack", symbol: "number", url: "slack://"),
        LinkableApp(id: "naver", name: "네이버", symbol: "magnifyingglass", url: "naversearchapp://"),
        LinkableApp(id: "navermap", name: "네이버 지도", symbol: "map.fill", url: "nmap://"),
        LinkableApp(id: "kakaomap", name: "카카오맵", symbol: "mappin.and.ellipse", url: "kakaomap://"),
        LinkableApp(id: "spotify", name: "Spotify", symbol: "music.note", url: "spotify://"),
        LinkableApp(id: "melon", name: "멜론", symbol: "music.note.list", url: "melonapp://"),
        LinkableApp(id: "toss", name: "토스", symbol: "wonsign.circle.fill", url: "supertoss://"),
        LinkableApp(id: "baemin", name: "배달의민족", symbol: "takeoutbag.and.cup.and.straw.fill", url: "baemin://"),
        LinkableApp(id: "coupang", name: "쿠팡", symbol: "cart.fill", url: "coupang://"),
        LinkableApp(id: "duolingo", name: "Duolingo", symbol: "character.book.closed.fill", url: "duolingo://"),
        LinkableApp(id: "nrc", name: "Nike Run Club", symbol: "figure.run", url: "nikerunclub://"),
        LinkableApp(id: "calendar", name: "캘린더", symbol: "calendar", url: "calshow://"),
        LinkableApp(id: "notes", name: "메모", symbol: "note.text", url: "mobilenotes://"),
        LinkableApp(id: "photos", name: "사진", symbol: "photo.fill", url: "photos-redirect://"),
        LinkableApp(id: "music", name: "음악", symbol: "music.quarternote.3", url: "music://"),
        LinkableApp(id: "maps", name: "지도", symbol: "map", url: "maps://"),
        LinkableApp(id: "shortcuts", name: "단축어", symbol: "square.2.layers.3d.fill", url: "shortcuts://"),
        LinkableApp(id: "safari", name: "Safari", symbol: "safari.fill", url: "x-web-search://"),
        LinkableApp(id: "settings", name: "설정", symbol: "gearshape.fill", url: UIApplication.openSettingsURLString)
    ]

    static func find(_ id: String?) -> LinkableApp? {
        guard let id = id else { return nil }
        return all.first { $0.id == id }
    }
}
