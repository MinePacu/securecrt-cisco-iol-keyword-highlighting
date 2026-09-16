# ASA SecureCRT v1 키워드 목록

플랜을 SecureCRT가 읽는 Keyword List V2 형식으로 옮긴 초안입니다. Cisco/VanDyke 공식 예제에서 확인한 출력 형식을 기준으로 만들었으며, 실장비와 SecureCRT 화면에서 최종 확인하기 전의 배포 후보입니다.

## 파일 선택

- ASA-SecureCRT-v1-Core.ini: 46개 규칙. syslog 심각도, 인터페이스 상태, HA 역할·인터페이스 이상·동기화, ASAv 라이선스, SLA Track, AAA 서버, VPN 상태, ACL, 기본 경로, 예약 reload와 물리 환경 실패를 포함합니다. 먼저 적용할 목록입니다.
- ASA-SecureCRT-v1-Extended.ini: 64개 규칙. Core 전체에 VPN 송수신, NAT/xlate, 연결, CPU·메모리, 버전·PID, running-config 구획, service-policy/ASP drop, resource `Denied`, OSPF 인접 상태 및 보류 인증서 등록을 추가합니다. 출력량이 많은 세션에서는 시범 적용 후 사용합니다.

두 파일은 독립적인 키워드 목록입니다. Extended 파일이 Core를 자동으로 상속하지 않으므로 하나를 선택해 적용합니다.

## SecureCRT 적용

1. SecureCRT의 Options / Global Options / Configuration Paths에서 현재 Configuration 폴더를 확인합니다.
2. 그 폴더의 Keywords 하위 폴더에 선택한 INI 파일을 복사합니다. Keywords 폴더가 없으면 생성합니다.
3. 세션의 Session Options / Terminal / Keyword Highlighting에서 파일명에 해당하는 목록을 선택하고 강조 표시를 활성화합니다.
4. 고급 강조 설정에서 Highlight Color를 활성화하고, 긴급·치명 규칙의 굵게 표시를 유지하려면 Highlight Bold도 활성화합니다. Reverse Video는 사용하지 않습니다. 정규식은 전체 일치 영역에 하나의 색상을 적용하므로, 줄 단위 규칙과 필드 단위 규칙이 겹치는지 확인합니다.
5. 필요하면 Default Session에 같은 목록을 지정해 기존·신규 세션에 적용합니다.

VanDyke의 공식 예제는 이 폴더 복사 방식과 제공 import 스크립트를 설명합니다: [INI 가져오기 안내](https://www.vandyke.com/support/scripting/scripting-examples/import-keyword-highlighting-ini-files.html). SecureCRT는 정규식과 phrase/substring 매칭을 지원합니다: [기능 안내](https://www.vandyke.com/products/securecrt/).

## 색상 값

파일의 색상 값은 공식 샘플과 같은 8자리 SecureCRT 값으로 기록했습니다. 화면에서 확인할 의도는 다음과 같습니다.

| 의미 | 의도한 표시 | 파일 값 |
|---|---|---|
| 긴급·치명 | 빨강 + 굵게 | 000000ff |
| 오류·상태 이상 | 주황 | 0066aaff |
| 누적 오류·주의 | 노랑 | 0066d8ff |
| 정상 상태 | 초록 | 009cd48b |
| 정보·Active·permit | 하늘색 | 00ffc878 |
| Standby·deny | 보라 | 00e7a7c4 |
| 관리적 비활성·0 | 회색 | 00a6a09a |
| 미매칭 기본색 | 회색 계열 | 00d4d4d4 |

마지막 .*|setasregextosetdefaultcolor 항목은 미매칭 텍스트를 기본색으로 두기 위한 공식 Cisco 키워드 파일의 방식을 따른 것입니다. 실제 색상은 현재 세션의 색상표와 SecureCRT 버전에 따라 확인합니다.

## 운영 상태 규칙과 보류 항목

- `show failover`의 `Interface ...: Failed`는 빨강, `Normal (Waiting)`은 주황, `Sync Done`/`Sync Skipped`는 초록으로 표시합니다. 분리형 `Active`/`Standby Ready`는 뒤의 `None`·`Ifc Failure`·`Comm Failure`에 상관없이 역할 토큰만 각각 초록·보라로 표시합니다. `Last Failure Reason`은 해소 뒤에도 남는 이력이므로 강조하지 않습니다.
- ASAv의 `Unlicensed`, `No active entitlement:`(뒤 설명 포함), `Status: Noncompliant:`은 빨강입니다. `Compliant`는 초록입니다. SLA Track의 `Reachability is DOWN`, AAA의 `Server status: FAILED`, 물리 장비의 `Failure Detected`/`Power Problem`도 빨강입니다.
- 예약된 reload는 주황으로 표시합니다. 이는 장애가 아니라 운영자가 놓치면 안 되는 변경 상태입니다.
- Extended의 service-policy drop, ASP drop reason, resource `Denied`는 누적값이므로 노랑입니다. 정상 ACL 차단도 ASP drop에 포함될 수 있으므로 빨강으로 단정하지 않습니다.
- Extended의 OSPF `FULL`만 초록입니다. `DOWN`/`INIT`/`EXSTART`/`EXCHANGE`/`LOADING`은 주황이지만 지속 시간은 정규식만으로 판단할 수 없습니다.
- CPU·메모리의 임계치, NAT hit의 증감, VPN 세션 0개 여부, BGP 요약 행, `show blocks`의 숫자 전용 행, 인증서 만료일 임계치는 정규식만으로 현재 장애를 판단하기 어려워 넣지 않았습니다. 인증서는 `Pending terminal enrollment`만 주황입니다.
- Severity 6 syslog는 기본색입니다. 일반 단어 error, fail, deny, down 단독 규칙은 넣지 않았습니다.

## 확인 결과

- Core: 선언된 46개 규칙과 실제 46개 항목이 일치합니다.
- Extended: 선언된 64개 규칙과 실제 64개 항목이 일치합니다.
- 두 목록 모두 `Regex Line Mode=1`을 명시하며, 행 앵커를 사용하는 규칙은 이 설정을 전제로 합니다.
- 두 파일의 정규식과 색상 필드 형식을 오프라인에서 검사했고, 현재 Cisco 예제·ASAv 9.8(1) 원문 형태의 양성·음성 60건을 확인했습니다.
- 2026-09-15 PNETLab `/opt/unetlab/labs/Study/260915_ASA-Failover.unl`의 ASAv 9.8(1) 두 대에서 실제 콘솔 출력을 확인했습니다. Primary Active/Secondary Standby Ready의 한 줄형·분리형 HA 상태, 상세·요약 인터페이스, 0이 아닌 L2 decode drops, NAT 구획·hit, CPU·메모리, 버전·PID, running-config 구획을 포함한 양성 20건과 오탐 방지 9건이 자동 검사에 통과합니다. 검사는 `tests/AsaKeywordLists.Tests.ps1`에 기록했습니다.
- 위 실장비 검증은 PNETLab 텔넷 콘솔에서 원문을 수집한 결과입니다. SecureCRT 네이티브 색상 렌더링 검증으로 확대 해석하지 않습니다.
- 2026-09-15 사용자 제공 SecureCRT 화면에서 Primary Active 하늘색, Secondary Standby Ready 보라, NAT 구획·hit·`TCP PAT`·`object network` 하늘색 표시를 확인했습니다. 같은 화면에서 `show failover` 통계의 `TCP conn`/`UDP conn`이 하늘색으로 표시되는 오탐도 확인하여 Extended 연결 규칙에서 바로 뒤 토큰이 `conn`인 경우를 제외했습니다. 재설치 후 사용자 후속 화면에서 `TCP conn`/`UDP conn`은 기본색으로 복원되고 실제 `TCP PAT`는 하늘색을 유지하며 Active/Standby 강조도 보존된 것을 확인했습니다.
- 당시 42개였던 Extended를 SecureCRT가 불러온 뒤 설치 파일에 BOM, 동일한 V3 규칙, `List Name`을 추가해 다시 저장하는 것을 확인했습니다. 그 재저장본은 V2/V3 42개, `Match Case=1`, `Regex Line Mode=1`, 수정된 연결 규칙을 모두 유지했습니다. 현재 64개 확장본은 이 재직렬화 검증 전이므로, 설치 직후 원본과 일치했던 SHA256이 앱 사용 후 달라지는 현상만으로 파일 손상으로 판단하지 않습니다.
- 해당 랩에서는 syslog가 비활성화돼 있었고 ACL·VPN SA·기본 경로가 없었습니다. 따라서 syslog 양성, ACL permit/deny, IKE/IPsec 양성, 정적 기본 경로, Active/Active Group 상태는 Cisco 예제 기반 자동 검사 상태이며 후속 실제 화면 검증 대상입니다.
- 2026-09-15 확장한 HA 인터페이스/동기화, ASAv 라이선스, SLA Track, AAA, reload, 물리 환경, service-policy/ASP/resource/OSPF/인증서 등록 상태는 Cisco 공식 출력 형태를 포함한 자동 회귀 62건으로 검증했습니다. 이 랩에는 SLA·AAA·OSPF·물리 센서가 구성돼 있지 않아 이 항목의 SecureCRT 네이티브 색상 검증은 아직 하지 않았습니다.
- 2026-09-15 사용자 제공 ASA 화면에서 `show failover state`의 `Sync Done` 초록 및 두 `Warning: ASAv platform license state is Unlicensed.`/`ASAv Platform License State: Unlicensed` 빨강을 확인했습니다. 같은 화면의 `No active entitlement: ...`는 콜론 뒤 설명 때문에 기존 패턴에 걸리지 않아, 후속 소스에서는 그 변형을 포함하도록 수정했습니다. 수정본의 네이티브 재설치 확인은 아직 남아 있습니다.
- 후속 재설치 화면에서 `No active entitlement: ...` 빨강, `Active Ifc Failure`의 Active 초록, `Sync Done` 초록을 확인했습니다. 마지막 재설치 화면에서 `Standby Ready Ifc Failure`의 Standby Ready 보라까지 확인했으며, 뒤의 `Ifc Failure`와 `inside: Failed` 이력은 기본색으로 유지됐습니다.
