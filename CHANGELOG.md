# Changelog

이 파일은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 형식을 따르며, 버전 번호에는 [Semantic Versioning](https://semver.org/lang/ko/) 원칙을 적용합니다.

## [Unreleased]

## [0.1.5-alpha.9] - 2026-08-26

### Fixed

- Restored alpha-4 ordering for the BGP summary and neighbor rule blocks in both V2 and V3 keyword lists while preserving all 325 rules. / V2와 V3 키워드 목록의 325개 규칙을 그대로 보존하면서 BGP summary 및 neighbor 규칙 블록을 alpha-4 순서로 복원했습니다.

## [0.1.5-alpha.8] - 2026-08-26

### Changed

- Changed the omitted, blank-input, and `-Force` keyword-list default from V2 to V3; explicit `-KeywordListVersion V2` remains supported. / 키워드 목록 버전을 생략하거나 빈 입력 또는 `-Force`로 실행할 때의 기본값을 V2에서 V3로 변경했으며, 명시적인 `-KeywordListVersion V2`는 계속 지원합니다.

## [0.1.5-alpha.7] - 2026-08-26

### Fixed

- Separated Cisco BGP route status markers and refined BGP header/value highlighting for tested IOS/IOL output in the V2 and V3 keyword lists.

## [0.1.5-alpha.6] - 2026-08-25

### Fixed

- `show ip neighbors`의 `state = ...` 상태 정규식을 네 개의 짧은 규칙으로 분리해 SecureCRT의 긴 정규식 파서 회귀를 방지했습니다.
- V2/V3 키워드 목록의 상태 규칙과 항목 수 메타데이터를 동기화하고, 모든 상태 표기와 V3 매핑에 대한 회귀 검증을 추가했습니다.

## [0.1.5-alpha.5] - 2026-08-25

### Fixed

- BGP 전용 규칙의 우선순서를 generic 상태 규칙보다 앞으로 복구하고, `show ip bgp summary`의 neighbor `V` 값과 `show ip bgp neighbors`의 `state = ...` 출력을 다시 강조하도록 정리했습니다.
- `show ip bgp`의 iBGP `i` 규칙이 `*>`/`r>` 상태 접두사를 함께 먹지 않고, 경로 줄의 단일 `i` 마커만 따로 강조하도록 조정했습니다.

## [0.1.5-alpha.4] - 2026-08-25

### Added

- 기존 320개 V2 규칙을 보존한 `PNET-Cisco-Dark-V3.ini`를 추가했습니다. V3 행은 V2의 패턴·색상·세 번째 필드를 유지하고 `00000001` 네 번째 필드를 추가합니다.
- 설치기에서 대화형 V2/V3 선택과 `-KeywordListVersion V2|V3` 자동화 옵션을 지원합니다. Enter 또는 `-Force`에서 생략한 경우 V2를 선택합니다.
- 런처가 V2와 V3 키워드 파일을 모두 임베드하고 추출하도록 확장했습니다.

### Changed

- V2는 `PNET-Cisco-Dark.ini`, V3는 `PNET-Cisco-Dark-V3.ini`로 SecureCRT Keywords 폴더에 공존할 수 있으며, `Default.ini`의 `Keyword Set`은 선택한 basename을 가리킵니다.
- self-update와 rollback이 V3 자산을 함께 검증·스테이징하며, 요청한 historical tag에 V3 자산이 없으면 V2로 대체하지 않고 명확한 오류를 냅니다.

## [0.1.5-alpha.3] - 2026-08-25

### Fixed

- 런처가 `%TEMP%\Install-KeywordHighlight-Setup`에 기존 파일이 있어도 최신 임베디드 설치 파일로 덮어쓰도록 수정했습니다.

## [0.1.5-alpha.2] - 2026-08-25

### Added

- `show ip bgp neighbor(s)`의 `NEXT_HOP is always this router for eBGP paths` 문구에서 들여쓰기·다중 공백 변형 및 오탐을 검증하는 회귀 테스트를 추가했습니다.

### Fixed

- `show ip bgp neighbor(s)`의 eBGP 경로에 나타나는 `NEXT_HOP is always this router for eBGP paths` 문구를 색상 강조하도록 보강했습니다.
- SecureCRT `Keyword List` 메타데이터를 320개로 갱신했습니다.

## [0.1.5-alpha.1] - 2026-08-25

### Added

- Cisco BGP 출력과 키워드 목록 메타데이터를 검증하는 관련 회귀 테스트를 추가하고, `Keyword List` 메타데이터를 갱신했습니다.

### Fixed

- Cisco `show ip bgp`의 `>`, `r`, `*` 상태 코드를 서로 다른 색상으로 구분하고, Origin codes의 `i`와 경로 행의 iBGP `i`를 구분하도록 보강했습니다.
- Cisco `show ip bgp`의 `Metric`, `LocPrf`, `Weight`, `Path` 제목과 값을 색상 강조하도록 보강했습니다.
- Cisco `show ip bgp summary`의 local AS 및 `V`/`AS`/`State` 항목을 색상 강조하도록 보강했습니다.
- Cisco `show ip bgp neighbor(s)`의 remote AS와 `Last read`/`last write`, hold time, keepalive, seconds 항목을 색상 강조하도록 보강했습니다.
- Cisco `show ip route`의 BGP `B` 코드를 파란색에서 고대비 주황색으로 변경했습니다.

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
