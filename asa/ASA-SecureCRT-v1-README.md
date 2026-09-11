# ASA SecureCRT v1 키워드 목록

플랜을 SecureCRT가 읽는 Keyword List V2 형식으로 옮긴 초안입니다. Cisco/VanDyke 공식 예제에서 확인한 출력 형식을 기준으로 만들었으며, 실장비와 SecureCRT 화면에서 최종 확인하기 전의 배포 후보입니다.

## 파일 선택

- ASA-SecureCRT-v1-Core.ini: 31개 규칙. syslog 심각도, 인터페이스 상태, HA 역할·실패, VPN 상태, ACL, 기본 경로를 포함합니다. 먼저 적용할 목록입니다.
- ASA-SecureCRT-v1-Extended.ini: 42개 규칙. Core 전체에 VPN 송수신, NAT/xlate, 연결, CPU·메모리, 버전·PID, running-config 구획을 추가합니다. 출력량이 많은 세션에서는 시범 적용 후 사용합니다.

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

## 이번 초안의 보류 항목

- 일반적인 HA 인터페이스 Failed 행은 별도 검증 대상으로 남겨 두었습니다. 현재는 Cisco 공식 show failover state 예제와 일치하는 Group 상태 Failed만 빨강으로 표시합니다.
- Interface ...: Normal (Waiting) 같은 HA 인터페이스 상태는 Waiting과 Not-Monitored의 의미를 확인하기 전에는 자동 정상색을 주지 않습니다.
- CPU·메모리의 임계치, NAT hit의 증감, VPN 세션 0개 여부는 정규식만으로 현재 장애를 판단하지 않습니다.
- Severity 6 syslog는 기본색입니다. 일반 단어 error, fail, deny, down 단독 규칙은 넣지 않았습니다.

## 확인 결과

- Core: 선언된 31개 규칙과 실제 31개 항목이 일치합니다.
- Extended: 선언된 42개 규칙과 실제 42개 항목이 일치합니다.
- 두 파일의 정규식과 색상 필드 형식을 오프라인에서 검사했고, Cisco 예제 형태의 양성 38건과 오탐 방지 6건을 확인했습니다.
- Cisco 예제 형태의 정상·관리적 비활성·down, hitcnt 0/양수, HA의 분리형 상태·그룹 Failed, IKE/IPsec, NAT, CPU·메모리 샘플로 후속 SecureCRT 화면 검증을 진행해야 합니다.
