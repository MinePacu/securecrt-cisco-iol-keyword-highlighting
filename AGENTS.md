# 프로젝트 작업 지침

이 파일은 이 프로젝트를 수정하는 AI 에이전트를 위한 지침이다. 2026-09-05 사용자 화면 검증까지 반영했다. 과거 대화 없이 시작하더라도 먼저 이 파일과 `docs/NAT-Highlighting-Status.md`를 읽는다. 이후 새로운 사용자 요청이나 실제 검증 결과가 있으면 그 근거와 함께 갱신한다.

## 유지해야 할 사용자 결정과 현재 기준

- 사용자는 **NAT 전용 목록으로 전환하지 않고 통합 목록을 유지**하기로 결정했다. 새 요청 없이 별도 목록 선택을 운영 해결책으로 다시 제안하지 않는다.
- 운영 파일은 `PNET-Cisco-Dark.ini`(V2), `PNET-Cisco-Dark-V3.ini`(V3)이다. 기본 설치 대상은 V3다. `PNET-Cisco-NAT-V3.ini`와 `tests/NAT-*Probe*.ini`는 비교/진단 자료이며 기본 설치 대상으로 바꾸지 않는다.
- 현재 두 운영 목록은 432개 행, 선언값 `000001B0`이다. 행 수를 바꾸면 선언값·V2/V3 대응·테스트·README를 함께 갱신한다. 이 수치는 영구 제한이 아니라 현재 기준이다.
- 통합 V3를 재설치한 뒤 사용자 화면에서 NAT, ACL, 일부 라우팅 출력이 정상인 것을 확인했다. 이미 확인한 사례를 다시 처음부터 진단하지 않는다.

## 실제 화면에서 확인한 범위

| 사례 | 확인 결과 |
| --- | --- |
| ICMP NAT 행 | 네 주소와 `:39829` 식별자 전체가 골드/시안/하늘색/보라 |
| 정적 NAT 행 | Inside global 골드, Inside local 시안, 뒤쪽 `---` 은색 |
| Standard/Extended ACL | 제목 흰색, permit 행 전체 초록, deny 행 전체 빨강; IP와 match 횟수 포함 |
| Gateway of last resort | gateway 및 network IP가 일반 노란색 유지; NAT 보라색 오탐 없음 |
| 화면에 보인 정적/connected/local 경로 | 주소·경로 코드·인터페이스 등의 기존 강조 유지 |
| 프롬프트/오류 | 프롬프트 노랑, Invalid 빨강 유지 |

이 결과는 제공된 화면의 사례에 한정한다. 전체 BGP, 모든 라우팅 출력, TCP/UDP, 임의의 문장에 대한 네이티브 검증 완료로 확대 해석하지 않는다. 화면 증거는 사용자 제공 자료이며 Temp 경로의 원본 이미지가 다음 세션에도 남아 있다고 가정하지 않는다.

## ASA 목록과 통합 상태

- `asa/ASA-SecureCRT-v1-Core.ini`와 `asa/ASA-SecureCRT-v1-Extended.ini`는 별도 Keyword List V2 파일이며, ASA 규칙의 비교·회귀 자료로 유지한다. 기본 설치 대상을 이 목록으로 바꾸지 않는다.
- 두 목록은 `Match Case=1`, `Regex Line Mode=1`을 유지한다. Core는 46개, Extended는 64개 규칙이다.
- 2026-09-15 PNETLab `/opt/unetlab/labs/Study/260915_ASA-Failover.unl`의 ASAv 9.8(1) 두 대에서 콘솔 원문을 수집했고, 사용자 제공 SecureCRT 화면에서 Extended의 Primary Active 하늘색, Secondary Standby Ready 보라, NAT 구획·hit·`TCP PAT`·`object network` 하늘색을 확인했다.
- 최초 화면에서 `show failover` 통계의 `TCP conn`/`UDP conn`이 연결 종류 규칙에 걸리는 오탐이 있었다. Extended 규칙을 `^[ \t]*(TCP|UDP|ICMP)[ \t]+(?!conn(?:[ \t]|$))`로 좁힌 뒤 재설치했고, 후속 화면에서 두 통계 토큰은 기본색, 실제 `TCP PAT`는 하늘색으로 유지되는 것을 확인했다. 이 예외를 제거하거나 다시 넓히지 않는다.
- 당시 42개였던 V2 Extended를 SecureCRT가 불러온 뒤 설치 파일에 BOM과 동일한 V3 규칙 및 `List Name`을 추가해 재저장하는 동작을 확인했다. 현재 64개 확장본은 재설치·재저장 검증 전이므로, 설치 직후 SHA256 일치와 앱 사용 후 재직렬화된 파일의 구조 검증을 구분한다.
- 해당 랩은 syslog 비활성, ACL·VPN SA·기본 경로 부재 상태였다. 이 항목과 Active/Active Group 상태의 양성 네이티브 검증까지 완료한 것으로 확대 해석하지 않는다.
- 2026-09-15에 HA 인터페이스 `Failed`/`Normal (Waiting)`, 동기화 완료, ASAv 라이선스 준수 상태, SLA Track, AAA 서버 상태, 예약 reload, 물리 환경 실패를 Core에 추가했다. Extended에는 0이 아닌 service-policy·ASP drop, resource `Denied`, OSPF 인접 상태, 보류 중인 인증서 등록을 추가했다. 이 추가 항목은 Cisco 공식 출력 기반 자동 테스트만 통과했으며, 현재 랩의 구성 부재 항목은 SecureCRT 네이티브 검증 완료로 보고하지 않는다.
- 추가 화면 검증에서 `show failover state`의 `Sync Done` 초록, ASAv의 경고형·상태형 `Unlicensed` 빨강을 확인했다. `No active entitlement: ...` 변형은 콜론 뒤 설명 때문에 기존 규칙에서 빠져 패턴을 확장했고, 이 수정본은 재설치 전이다. `Active Ifc Failure`는 현재 Active 상태와 잔존한 Failure Reason을 혼동하지 않도록 Active 토큰만 초록으로 매칭한다.
- 후속 재설치 화면에서 `No active entitlement: ...` 빨강과 `Active Ifc Failure`의 Active 초록을 확인했다. 마지막 재설치 화면에서 `Standby Ready Ifc Failure`의 Standby Ready 보라까지 확인했고, 뒤의 `Ifc Failure`와 `inside: Failed` 이력은 기본색으로 남았다.
- ASA 구조·정규식·실출력 회귀는 `pwsh -NoProfile -File tests/AsaKeywordLists.Tests.ps1`로 검사한다.
- 2026-09-15 사용자가 요청한 통합 작업으로 Extended의 63개 정규식(별도 목록의 default-color fallback 제외)을 V2/V3의 `ASA_FIREWALL_OPERATIONAL_STATES` 블록으로 병합했다. 이 블록은 `BGP_SHOW_IP` 뒤, 범용 `CRITICAL_ERRORS_AND_DOWN_STATES` 앞에 있다. 재설치 뒤 사용자 제공 통합 V3 화면에서 failover의 Primary/Secondary·Active·Standby Ready·Sync Done, `Ifc Failure`/`inside: Failed` 이력 기본색, ASAv entitlement/Unlicensed 빨강, `show nat` 정책·hit 카운터와 `show xlate`의 `NAT from`을 확인했다. 이어진 `show access-list` 화면에서 ASA ACL permit 접두부와 `hitcnt=10` 시안, `hitcnt=0` 회색도 확인했다. 화면에 실제 deny ACL 행과 `TCP PAT` 행은 없으므로 이 두 사례는 통합 네이티브 검증 완료로 보고하지 않는다.

## 검증된 구현과 순서

현재 블록 순서를 보존한다:

1. `SHOW_ACCESS_LISTS`: ACL 행 전체 강조가 NAT보다 우선.
2. `NAT_CONTEXT_GUARDS`: 알려진 비-NAT 문맥의 IPv4를 일반 주소색으로 보호.
3. `SHOW_IP_NAT_TRANSLATIONS`: Suffix 주소 규칙을 Inside global → Inside local → Outside local → Outside global 순서로 배치. **`---` 규칙은 네 주소 규칙 뒤**.
4. `BGP_SHOW_IP` 뒤의 `ASA_FIREWALL_OPERATIONAL_STATES`: ASA 전용 규칙을 범용 오류/정상 상태 규칙보다 먼저 평가한다.
5. 나머지 기존 블록. 일반 IPv4 규칙을 NAT 앞에 무작정 올리지 않는다.

NAT는 주소 토큰에서 매칭을 시작하고 lookahead로 뒤에 남은 endpoint/`---` 필드 수(3/2/1/0)를 검사한다. 공인/사설 IP 여부로 열을 판단하지 않는다. 실제 패턴은 운영 INI를 기준으로 읽고, 문서의 요약을 그대로 새 정규식으로 재구현하지 않는다.

문맥 보호는 `host/network/to/is/from/via/neighbor/Originator:/list:` 뒤 또는 쉼표 뒤 IPv4에 적용한다. 보호 조건 변경 시 NAT 정상 행을 먼저 매칭해 버리지 않는지 검사한다. 기존 BGP 경로 값 규칙의 next-hop 뒤 숫자 metric 조건도 유지한다. 이를 느슨하게 하면 정적 NAT 주소 행과 충돌할 수 있다.

## 실패한 탐색을 반복하지 말 것

| 과거 접근 | 관찰 결과 및 지침 |
| --- | --- |
| `^...\K`로 앞쪽 열을 소비한 뒤 강조 시작점 이동 | 주소 열 및 진단의 Outside global 강조 실패. 운영 NAT 구현으로 되돌리지 않는다. |
| `DEFINE`와 이름 있는 서브패턴 호출 | 짧은 진단의 `---`도 강조 실패. PCRE 통과만 보고 다시 채택하지 않는다. |
| `(?<=^.{N})` 위치 검사 | 사진 배치용 Position 진단에서도 주소 강조 실패. 화면 폭에 맞춘 offset 나열로 재시도하지 않는다. |
| 행 시작 lookbehind 안의 lookahead | Probe2에서 제목·프로토콜만 성공하고 주소는 실패. 단순 lookbehind 성공과 혼동하지 않는다. |
| 약 3,000자 복합 규칙/128개 위치 열거 | 실제 표시 실패. `tests/Update-NatMatchers.ps1`은 의도적으로 비활성화됐으므로 복구하거나 실행 우회하지 않는다. |
| `---`를 주소보다 먼저 강조 | Suffix의 ICMP는 성공했지만 정적 NAT 주소는 실패. 규칙 하나를 맨 뒤로 이동한 뒤 둘 다 성공했다. |

단순 lookahead, 짧은 고정 길이 lookbehind, 여러 단어 및 endpoint 내부 부분 문자열은 1차 화면에서 성공했다. 따라서 “모든 lookbehind가 미지원”이라고 단정하지 않는다. 마찬가지로 실패를 SecureCRT 전체의 문법 미지원, 특정 최대 길이, 내부 버퍼 분할 구현으로 단정하지 않는다. 확정된 것은 해당 규칙과 순서의 실제 결과다. 새로운 근거로 재검증할 때만 실패한 접근을 다시 다룬다.

## 잔여 위험과 변경 원칙

- Suffix는 명령을 자동 인식하지 않는다. 보호되지 않은 문장 끝 IP(예: `Peer 198.51.100.1`)에는 NAT 색이 붙을 수 있다. 불완전한 NAT 행은 열색이 이동할 수 있다.
- 문맥 보호는 알려진 오탐을 줄일 뿐 완전한 NAT 판별기가 아니다. 포트 필수 조건도 일반 IP:port 설명의 오탐을 해결하지 못하고 정적 NAT를 제외한다.
- IPv6, verbose, 화면 줄바꿈, 비정상 주소/포트는 지원을 보장하지 않는다.
- 사용자에게서 새 오탐의 원문/화면을 확보하고 해당 사례의 최소 보호 규칙부터 검토한다. NAT·ACL·라우팅의 기존 성공 사례를 보존한다.
- 변경은 요청 범위로 제한한다. 단순 결과 확인 요청을 파일 수정·재설치·장비 명령 실행 권한으로 확대하지 않는다.

## 테스트와 증거 수준

프로젝트 루트에서 개별 명령으로 실행하고 각 종료 코드를 확인한다:

```powershell
pwsh -NoProfile -File tests/KeywordListVersion.Tests.ps1
pwsh -NoProfile -File tests/NatTranslations.Tests.ps1
pwsh -NoProfile -File tests/KeywordIni.Tests.ps1
pwsh -NoProfile -File tests/AsaKeywordLists.Tests.ps1
```

- 앞의 두 검사는 현재 통과 기준이다. NAT 검사는 버전별 정상 70개 구간/색상, 후보 시작 위치, 6개 문맥 보호 사례 등을 확인한다.
- `KeywordIni.Tests.ps1`은 2026-09-15 실행에서 408행의 리터럴 `…16433 tokens truncated…` 때문에 PowerShell parser error로 시작조차 하지 못했다. 이는 이번 ASA 병합과 무관한 기존 테스트 파일 손상/불일치다. 원본 근거 없이 해당 테스트를 복구하거나 성공 처리하지 말고, 새 ASA 회귀와 구분한다.
- Git/PCRE 검사는 SecureCRT 검사가 아니다. .NET 후보 위치·우선순위 모델도 실제 렌더러의 처리 구간을 재현한다고 주장하지 않는다. 실패한 과거 패턴도 자동 검사에서는 통과했다.
- 번들 Git의 `grep -o --column`은 한 줄의 후속 매치에서 실제 시작점 대신 재검색 시작 offset을 보고한 사례가 있다. 정확한 구간 검사에는 현재 테스트의 .NET 계산을 사용한다.
- `NatProbe2/3/4`, `NatDedicated` 검사는 진단 및 역사적 비교 자료다. 특히 Probe4의 `[KNOWN UNSAFE]`는 보호 없는 Suffix 오탐을 의도적으로 재현한다. 이를 새 통합 실패로 잘못 해석하지 않는다.
- 새 규칙/우선순위를 설치하면 실제 SecureCRT 출력으로 추가 확인한다. 보고할 때 파일 구조 통과, 정규식 통과, 실제 화면 확인을 구분한다.

## 파일 형식과 설치

- V2/V3의 패턴·색상·순서를 동기화한다. 행 앞 공백, 메타데이터, V3의 추가 필드 및 List Name을 보존한다. 빈 행을 INI 내부에 넣지 않는다.
- `Match Case=1`, `Regex Line Mode=1`을 유지한다. 색상 DWORD를 RGB 표기로 착각하지 않는다. 예: 골드 `0000D7FF`, 시안 `00FFFF00`, 하늘색 `00FACE87`, 보라 `00EE82EE`.
- 로컬 파일 편집에는 `apply_patch`를 사용하고 사용자 변경을 보존한다. 문서 작업만으로 INI/설치 파일을 바꾸지 않는다.
- 재설치가 요청된 경우 로컬 수정본이 self-update로 덮이지 않도록 **`-SkipUpdate`**를 사용한다.

```powershell
pwsh -NoProfile -File .\Install-KeywordHighlight.ps1 -KeywordListVersion V3 -SkipUpdate
```

- 이 사용자의 확인된 Config 경로는 `C:\Users\MinePacu\AppData\Roaming\VanDyke\Config`다. 다른 환경에 이 경로를 하드코딩하지 말고 재확인한다. 쓰기 권한이 필요하면 제공된 승인 절차를 따른다.
- 설치 전 실행 여부/대상을 확인한다. `-Force`는 실행 중 경고와 덮어쓰기 확인을 건너뛰며 앱 재저장 위험이 있다. 연결을 임의 종료하지 않는다.
- 설치 후 백업 생성과 원본/설치본 SHA256 일치를 확인한다. 파일 일치는 화면 적용 성공의 증거가 아니다.
- Default.ini 설정이 바뀌어도 이미 열린 세션의 선택은 바뀌지 않는다. 진단/NAT 전용 목록이 선택돼 있으면 `PNET-Cisco-Dark-V3`를 선택해야 한다. 필요 시 작업 저장 후 재시작하도록 안내한다.
- UI 검증이 필요하면 그 세션에 제공된 스킬·도구 지침을 먼저 읽는다. 이 작업 당시 Computer Use는 터미널 앱 UI 자동 조작을 금지해 사용자 화면으로 검증했다. 같은 제한이 있으면 다른 UI 자동화 경로로 우회하지 않는다.

## 문서 갱신

새 화면 결과를 얻으면 이 파일과 `docs/NAT-Highlighting-Status.md`, 관련 README의 검증 상태를 함께 갱신한다. 과거 Probe 문서의 “대기/가설”과 최신 확인 결과를 구분하고, 확인된 통합 성공 사례를 다시 미확인 상태로 되돌리지 않는다.
