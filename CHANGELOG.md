# Changelog

이 파일은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 형식을 따르며, 버전 번호에는 [Semantic Versioning](https://semver.org/lang/ko/) 원칙을 적용합니다.

## [Unreleased]

## [0.1.5] - 2026-08-26

### Added

- Added the V3 keyword list alongside V2, with V3 metadata and SecureCRT-compatible mappings, while preserving the synchronized 325-rule lists. / V2와 함께 V3 키워드 목록을 추가하고 V3 메타데이터와 SecureCRT 호환 매핑을 제공하면서 동기화된 325개 규칙을 유지했습니다.
- Added explicit V2/V3 installer selection, V2/V3 coexistence, launcher embedding/extraction, tagged rollback validation, and regression coverage for the installer, keyword metadata, BGP output, and V2/V3 synchronization. / 설치기의 V2/V3 명시 선택, V2/V3 공존, 런처 임베드·추출, 태그 rollback 검증과 설치기·키워드 메타데이터·BGP 출력·V2/V3 동기화 회귀 검증을 추가했습니다.

### Changed

- Omitted, blank-input, and `-Force` keyword-list selection now defaults to V3 without a prompt; explicit `-KeywordListVersion V2` or `V3` remains supported. / 키워드 목록 선택을 생략하거나 빈 입력 또는 `-Force`로 실행하면 프롬프트 없이 V3를 기본 선택하며, `-KeywordListVersion V2` 또는 `V3` 명시는 계속 지원합니다.
- Restored the alpha-4 late-file ordering for BGP summary and neighbor rules, split the long `show ip neighbors` state matcher into four shorter rules, and removed internal blank lines from V2/V3 files. / BGP summary 및 neighbor 규칙을 alpha-4의 파일 후반 순서로 복원하고, 긴 `show ip neighbors` state 매처를 네 개의 짧은 규칙으로 분리했으며, V2/V3 파일의 내부 빈 줄을 제거했습니다.
- Hardened production self-update to scan paginated GitHub Releases, reject draft and SemVer prerelease tags on the stable channel, and retain tag/CHANGELOG validation; prerelease selection remains an explicit `-IncludePrerelease` opt-in. / 정식 self-update가 페이지를 넘겨 GitHub Releases를 검색하고 stable 채널에서 draft 및 SemVer prerelease 태그를 제외하며 tag/CHANGELOG 검증을 유지하도록 강화했으며, prerelease 선택은 명시적인 `-IncludePrerelease`로만 허용합니다.

### Fixed

- Added distinct colors for Cisco `show ip bgp` status markers `*`, `>`, and `r`, separated route-line iBGP `i` from Origin `i`, removed the incorrect color from the `i - internal` legend, and anchored RIB-failure `r` matching to avoid ordinary `r` false positives. / Cisco `show ip bgp`의 `*`, `>`, `r` 상태 코드를 서로 다른 색으로 구분하고, 경로 행의 iBGP `i`와 Origin `i`를 분리했으며, 잘못된 `i - internal` 범례 색상을 제거하고, 일반 `r` 오탐을 막도록 RIB-failure `r` 매칭을 앵커링했습니다.
- Highlighted `Metric`, `LocPrf`, `Weight`, and `Path` headings and values, local router ID, local AS, summary `V`/`AS`/`State` headings and values, and summary `Idle`/`Idle (Admin)` states. / `Metric`, `LocPrf`, `Weight`, `Path` 제목과 값, local router ID, local AS, summary의 `V`/`AS`/`State` 제목과 값, `Idle`/`Idle (Admin)` 상태를 색상 강조했습니다.
- Highlighted BGP neighbor remote AS, `Last read`, `last write`, hold-time, keepalive, seconds, `state = ...`, and `NEXT_HOP is always this router for eBGP paths` output. / BGP neighbor의 remote AS, `Last read`, `last write`, hold time, keepalive, seconds, `state = ...`, `NEXT_HOP is always this router for eBGP paths` 출력을 색상 강조했습니다.
- Changed the Cisco `show ip route` BGP `B` code from low-contrast blue to high-contrast orange. / Cisco `show ip route`의 BGP `B` 코드를 가독성이 낮은 파란색에서 고대비 주황색으로 변경했습니다.
- Made the launcher overwrite existing files under `%TEMP%\Install-KeywordHighlight-Setup` and hardened keyword validation against internal blank lines while preserving the selected list and `Default.ini` behavior. / 런처가 `%TEMP%\Install-KeywordHighlight-Setup` 아래 기존 파일을 덮어쓰도록 하고, 선택 목록과 `Default.ini` 동작을 유지하면서 내부 빈 줄 검증을 강화했습니다.

## [0.1.4] - 2026-08-22

### Added

- `Install-KeywordHighlight.ps1`을 감싸는 원클릭 Windows 실행 파일(`launcher/`, `Install-KeywordHighlight-Setup.exe` 폴더 배포)을 추가해, PowerShell 실행 정책을 수동으로 우회하지 않고도 설치 스크립트를 바로 실행할 수 있도록 했습니다.

### Fixed

- Cisco `show ip route` 출력의 프로토콜 코드와 `[AD/Metric]` 값을 SecureCRT에서 색상 강조하도록 보강했습니다.
- OSPF Neighbor가 `LOADING`에서 `FULL`로 전환되거나 `state FULL`로 동기화되는 로그의 `FULL` 상태를 색상 강조하도록 보강했습니다.
- Cisco `show ip protocols` 출력의 `Redistributing:` 항목과 OSPF의 `External Routes from`, EIGRP/RIP 및 주요 재분배 소스·연속 행을 색상 강조하도록 보강했습니다.
- Cisco `show ip protocols` 출력의 EIGRP `Distance: internal ... external ...` 및 RIP·OSPF·ODR의 `Distance: (default is ...)` 값을 색상 강조하도록 보강했습니다.
- Cisco `show ip route`의 범례와 실제 경로 행을 L/C/S·S*/R/I/M/B/D/EX/O 및 OSPF·IS-IS 세부 코드별로 서로 다른 색상으로 구분하도록 보강했습니다.
- 어두운 터미널 배경에서 가독성이 낮았던 `show ip route` 후보 기본 경로 및 정적·특수 경로 modifier의 색상을 고대비 흰색으로 조정했습니다.
- Cisco `show ip route`의 OSPF·EIGRP 요약 경로에서 `is a summary` 문구와 `Null0` 등 숫자형 Null discard next-hop을 별도 색상으로 강조하도록 보강했습니다.
- Cisco `show ip ospf virtual-links` 출력의 `Transit area 1`/`Transit area 0.0.0.1` 형식 문구, transit area ID, `OSPF_VL0`/`OSPF_VL1` 형식 식별자를 안정적으로 색상 강조하도록 보강했습니다(lookaround 없는 직접 매칭 규칙 적용).

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
