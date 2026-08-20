# Changelog

이 파일은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 형식을 따르며, 버전 번호에는 [Semantic Versioning](https://semver.org/lang/ko/) 원칙을 적용합니다.

## [Unreleased]

## [0.1.4-alpha.1] - 2026-08-20

### Fixed

- Cisco `show ip route` 출력의 프로토콜 코드와 `[AD/Metric]` 값을 SecureCRT에서 색상 강조하도록 보강했습니다.
- OSPF Neighbor가 `LOADING`에서 `FULL`로 전환되거나 `state FULL`로 동기화되는 로그의 `FULL` 상태를 색상 강조하도록 보강했습니다.
- Cisco `show ip protocols` 출력의 `Redistributing:` 항목과 OSPF의 `External Routes from`, EIGRP/RIP 및 주요 재분배 소스·연속 행을 색상 강조하도록 보강했습니다.
- Cisco `show ip protocols` 출력의 EIGRP `Distance: internal ... external ...` 및 RIP·OSPF·ODR의 `Distance: (default is ...)` 값을 색상 강조하도록 보강했습니다.

## [0.1.3] - 2026-08-19

### Added

- 자동 업데이트가 선택적 prerelease 조회, 태그 자산·CHANGELOG 버전 검증, 다운로드·검증·설치·재시작 단계 표시를 지원하도록 통합했습니다.
- 업데이트 흐름, `Default.ini` 보존 동작, OSPF·프롬프트 규칙, 키워드 목록 메타데이터를 검증하는 회귀 테스트를 추가했습니다.

### Changed

- 설치기가 `Default.ini`에서 필요한 설정만 대체하고, 인코딩·줄바꿈·idempotence를 보존하며, 원자적 백업·복원과 Windows PowerShell 5.1 호환성을 유지하도록 보강했습니다.

### Fixed

- OSPF Area·ABR·ASBR, 인터페이스 `Cost`·Passive interface·네트워크 타입을 SecureCRT 호환 규칙으로 색상 강조하도록 확장했습니다.
- Cisco IOS/XR 호스트 이름, 권한 및 config 하위 모드 프롬프트를 강조하고 키워드 목록 메타데이터를 실제 규칙 수와 동기화했습니다.

## [0.1.3-alpha.8] - 2026-08-19

### Fixed

- SecureCRT 키워드 목록의 항목 수 메타데이터를 실제 규칙 수와 동기화하여 호스트 이름과 권한 프롬프트 규칙이 로드되도록 보강했습니다.

## [0.1.3-alpha.7] - 2026-08-19

### Fixed

- SecureCRT 키워드 목록에서 정규식 라인 모드를 활성화하여 여러 줄 터미널 출력에 포함된 Cisco 호스트 이름·권한 프롬프트도 색상 강조하도록 수정했습니다.
- OSPF 출력의 `Area BACKBONE(0)` 및 숫자/IP 형식 Area가 SecureCRT에서 계속 색상 강조되도록 규칙을 분리했습니다.
- OSPF 인터페이스 출력의 `Cost` 및 네트워크 타입을 SecureCRT 호환 `\x20` 기반 전체 구문과 단일 토큰 fallback으로 강조하도록 보강했습니다.
- 원격 업데이트 확인·다운로드·검증·설치·재시작 단계와 업데이트된 설치기의 재진입 상태를 `[업데이트]` 메시지로 표시하도록 보강했습니다.

## [0.1.3-alpha.6] - 2026-08-19

### Fixed

- Cisco IOS `sh ip ospf` 출력의 ASBR 설명 문구도 노란색으로 강조하도록 키워드 규칙을 보강했습니다.
- Cisco IOS `show ip ospf interface [interface_name_number]` 출력의 `Cost: 숫자` 형식을 SecureCRT에서 안정적으로 금색 강조하도록 키워드 규칙을 조정했습니다.
- Cisco IOS/XR의 슬래시가 포함된 호스트 이름 프롬프트와 config 하위 모드 프롬프트도 SecureCRT에서 색상 강조하도록 규칙을 보강했습니다.

## [0.1.3-alpha.5] - 2026-08-19

### Fixed

- `Default.ini`의 기본 세션 설정이 이미 적용된 경우 불필요한 백업과 파일 쓰기를 건너뛰도록 설치 동작을 보강했습니다.
- `Default.ini` 부분 대체, 인코딩·줄바꿈 보존, idempotence, 중복 키, 원자적 백업·복원을 검증하는 독립 PowerShell 테스트를 추가했습니다.

## [0.1.3-alpha.4] - 2026-08-19

### Fixed

- OSPF 출력에서 standalone `IA`, `It is an area border router`, `Area BACKBONE(0)`을 색상 강조하면서 기존 `Area 1` 및 숫자/IP 형식 Area 인식도 유지하도록 키워드 규칙을 보강했습니다.

## [0.1.3-alpha.2] - 2026-08-19

### Fixed

- `sh ip ospf interface [interface_name]` 출력에서 `Cost`와 `Passive interface`를 색상 강조하도록 키워드 규칙을 보강했습니다.

## [0.1.3-alpha.1] - 2026-08-18

### Added

- `-IncludePrerelease`를 지정하면 GitHub Releases의 draft가 아닌 stable/prerelease 중 가장 높은 유효한 Semantic Version을 선택해 자동 업데이트할 수 있습니다. 기본 자동 업데이트는 계속 `main` 브랜치의 `CHANGELOG.md`를 사용합니다.

## [0.1.2] - 2026-08-18

### Added

- `Install-KeywordHighlight.ps1`이 공개 저장소의 더 최신 버전을 확인하고, 설치 자산을 갱신한 뒤 원래 인자로 다시 실행하도록 했습니다.
- 원격 업데이트를 건너뛰는 `-SkipUpdate` 옵션을 추가했습니다.
- `-RollbackVersion`과 `-Version` 별칭으로 Git 태그의 `PNET-Cisco-Dark.ini`를 설치 대상에 적용하는 기능을 추가했습니다.

### Changed

- 자동 업데이트의 SemVer 비교, `-WhatIf` 동작, 네트워크 실패 시 안전한 계속 진행을 문서화했습니다.
- 회귀 시 태그의 `CHANGELOG.md` 버전과 요청 버전을 검증하고, 현재 저장소의 ini는 변경하지 않도록 했습니다. `-RollbackVersion`과 `-Uninstall`의 충돌도 명확한 오류로 처리합니다.

### Fixed

- Windows PowerShell 5.1에서 `Split-Path -LiteralPath`와 `-Parent`를 함께 사용할 때 발생하는 매개 변수 집합 충돌을 수정했습니다.
- Windows PowerShell 5.1에서 `Get-ChildItem -LiteralPath`와 `-File` 필터링을 함께 사용할 때 발생하는 호환성 문제를 수정했습니다.

## [0.1.1] - 2026-08-16

### Added

- `Install-KeywordHighlight.ps1` Windows 설치/제거 스크립트와 `PNET-Cisco-Dark.ini`를 함께 배포해야 하는 설치 자산으로 명시했습니다.

### Changed

- `README.md`에 자동 설치/제거 절차와 백업/복원 동작을 문서화했습니다.

## [0.1.0] - 2026-08-15

### Added

- `PNET-Cisco-Dark.ini`를 최초 기준선으로 추가했습니다.
- `README.md`를 최초 기준선으로 추가했습니다.
