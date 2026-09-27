# 슬케줄러 iOS

`../README-iOS.md` 브리프를 기준으로 만든 네이티브 iOS 버전(Swift + SwiftUI, MVVM)입니다.

## 환경

- iOS 16.0 이상, 세로 전용, iPhone
- Xcode 14.2 / Swift 5.7에서 빌드와 테스트 확인
- 저장소는 SwiftData 대신 **Codable JSON 파일**입니다. 이 Mac(macOS 12)에서는 Xcode 15 이상을 쓸 수 없어서 SwiftData를 빌드할 수 없기 때문입니다. 데이터 파일은 App Group 컨테이너(`group.com.growv.seulkeduler`)에 두어 위젯과 공유하고, 백업/복원 파일도 같은 형식을 씁니다.

## 열기 / 빌드

```sh
open Seulkeduler.xcodeproj           # Xcode에서 Seulkeduler 스킴 실행
```

프로젝트 파일은 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 `project.yml`에서 생성합니다. 파일을 추가하거나 삭제했다면 `xcodegen generate`를 다시 실행하세요.

명령줄 빌드/테스트(Xcode가 `~/Downloads/Xcode.app`에 있는 경우):

```sh
export DEVELOPER_DIR=~/Downloads/Xcode.app/Contents/Developer
xcodebuild -project Seulkeduler.xcodeproj -scheme Seulkeduler \
  -destination 'platform=iOS Simulator,name=iPhone 14' test
```

- 단위 테스트 `SeulkedulerTests`: 스냅/자석/병합, 체크인, 목표 기반 종료, 반복 규칙과 자동 채움, 알림 표, 테마, 백업 왕복, 위젯 렌더링
- UI 테스트 `SeulkedulerUITests`: 체크인, 3가지 뷰, 할 일 폼, 이벤트 선택, 반복 설정, 블록 드래그/리사이즈/삭제, 시트 카드 드롭, 테마 편집
- 디버그 빌드에서 실행 인자 `-seedDemo`를 주면 시연용 데이터가 채워집니다(`-seedEmpty`는 빈 상태). 둘 다 기존 데이터를 덮어씁니다.

## 내 iPhone에 무료로 설치하기 (GitHub Actions + Sideloadly)

이 Mac(macOS 12 / Xcode 14.2)으로는 iOS 17 이상 기기에 직접 설치할 수 없습니다. 그래서 빌드는 GitHub의 macOS 26 + Xcode 26에 맡기고, 설치는 Sideloadly로 합니다.

1. **빌드**: `main` 브랜치에 `ios/` 변경을 push하면 `.github/workflows/ios-ipa.yml`이 실행됩니다. GitHub 저장소 **Actions** 탭에서 직접 실행(Run workflow)할 수도 있습니다.
2. **다운로드**: 끝난 실행 화면 아래 Artifacts에서 `Seulkeduler-ipa-N`을 받아 압축을 풀면 `Seulkeduler.ipa`가 나옵니다. 빌드가 실패하면 `build-log-N`을 확인하세요.
3. **설치**: [sideloadly.io](https://sideloadly.io)에서 Sideloadly를 받아 실행 → iPhone을 케이블로 연결 → `.ipa`를 끌어다 놓기 → Apple ID 입력 → Start.
4. **iPhone 설정**
   - 설정 > 일반 > VPN 및 기기 관리 > 내 Apple ID를 신뢰
   - 설정 > 개인정보 보호 및 보안 > 개발자 모드 켜기(재부팅)

알아 둘 점:
- 무료 Apple ID 서명은 **7일마다 만료**됩니다. 같은 `.ipa`를 다시 설치하면 되고, 데이터는 유지됩니다.
- 무료 Apple ID는 사이드로드 앱을 최대 3개까지, 앱 ID는 7일에 10개까지 쓸 수 있습니다. 슬케줄러는 앱과 위젯이 2개를 씁니다.
- App Group은 설치된 프로비저닝 프로필에서 읽어 옵니다. 서명 도구가 App Group을 등록하지 않으면 앱은 정상이고 **위젯만 비어 보입니다.**
- 비공개 저장소는 GitHub 무료 macOS 빌드 시간이 한 달 약 200분(빌드 1회당 5~10분)입니다. 공개 저장소면 제한이 없습니다.

## 실기기 / 배포 전에 할 일

- Signing & Capabilities에서 Team을 지정하세요. 두 타깃(앱, 위젯)에 App Group `group.com.growv.seulkeduler`이 있어야 위젯이 앱 데이터를 읽습니다.
- Bundle ID는 안드로이드와 같은 `com.growv.seulkeduler`(위젯은 `.widget`)로 되어 있습니다.

## 폴더

| 경로 | 내용 |
| --- | --- |
| `Shared/` | 앱·위젯 공용: 모델, JSON 저장소, 팔레트(`paletteForHue`), 폰트, 다이얼, 위젯 뷰 |
| `Seulkeduler/Store/` | `AppStore`(ViewModel), 타임라인 스냅 계산, 데모 데이터 |
| `Seulkeduler/Services/` | 로컬 알림, 햅틱, 연결 앱 목록 |
| `Seulkeduler/Views/` | 오늘(목록/원형/달력, 바텀시트, 모달), 할 일, 체크인, 설정 |
| `SeulWidget/` | WidgetKit 타임라인 |
| `Resources/` | 폰트(TTF 번들), 에셋 |

## 브리프 대비 iOS에서 결정한 것

- **아이콘**: SF Symbols를 rounded 디자인으로 썼습니다. Material Symbols 번들은 하지 않았습니다.
- **앱 연결**: iOS는 설치된 앱 목록을 조회할 수 없습니다. 그래서 URL 스킴을 등록해 둔 앱 23개(`LinkableApps.swift`) 중 `canOpenURL`로 설치가 확인되는 앱만 연결할 수 있습니다. 앱을 추가할 때는 `Info.plist`의 `LSApplicationQueriesSchemes`에도 스킴을 등록해야 합니다(`project.yml`에서 수정).
- **위젯 갱신**: 타임라인 한 번에 앞으로 2시간 동안의 분 단위 엔트리를 미리 넣고, 앱에서 데이터나 테마가 바뀌면 즉시 다시 불러옵니다. 앱을 오래 열지 않으면 iOS 갱신 예산 때문에 늦어질 수 있습니다.
- **리액션 애니메이션**: Lottie 대신 SwiftUI 애니메이션으로 만들었습니다(성공 = 바운스와 컨페티, 실패 = 처졌다가 복귀).
- **블록 이동**: iOS 스크롤과 충돌하지 않도록 블록 몸통을 0.2초 길게 누른 뒤 끌어야 합니다. 하단 그립은 바로 끌면 리사이즈됩니다.
- **내장 테마**: 모노톤 화이트만 고정이고, 딥퍼플/타이탄/포레스트 그린은 편집하거나 삭제할 수 있는 테마로 시드합니다.
- **폰트**: Playfair/Inter/Plex Mono에는 한글 글리프가 없어서 한글은 iOS 시스템 폰트로 대체되어 표시됩니다.
