# ASA SecureCRT 정규식 강조 상세 계획

## 구현 상태

계획을 다음 두 개의 SecureCRT 키워드 목록으로 옮겼다.

- ASA-SecureCRT-v1-Core.ini: 확인된 상태·심각도 중심의 46개 규칙
- ASA-SecureCRT-v1-Extended.ini: Core에 정보성 출력과 설정 구조·진단 카운터를 더한 64개 규칙

적용 절차와 보류 항목은 ASA-SecureCRT-v1-README.md에 기록했다.

작성: 2026-09-10. Cisco 공식 출력 예제를 기준으로 설계. 서브에이전트 미사용.
공식 예제로 출력 계열을 확인했으며 모든 ASA 버전의 동일 출력을 보장하지 않는다. SecureCRT 실행 검증 전의 설계안이다.

## 1. 적용 전제

- SecureCRT의 정규식 옵션과 phrases/substrings 매칭을 사용한다. 단어 전용 모드는 사용하지 않는다. [제품 안내](https://www.vandyke.com/products/securecrt/), [8.7 기능 안내](https://www.vandyke.com/aboutus/news/pressreleases/securecrt/securecrt87b.html)
- 대소문자를 구분한다. 공백은 `[ \t]`로 표현하여 줄을 넘지 않는다.
- lookbehind, 그룹별 색상, 명령 실행 문맥 추적에 의존하지 않는다. **정규식 전체 일치 부분**에 한 가지 색상이 적용되는 설계다. 연결 종류 규칙에는 실제 SecureCRT 화면에서 확인된 `show failover`의 `TCP conn`/`UDP conn` 오탐을 제외하기 위한 짧은 negative lookahead 하나만 사용한다.
- 표의 정규식은 그대로 입력할 완성 패턴이다. 코드 블록의 역슬래시를 추가 이스케이프하지 않는다. INI 직렬화는 별도 문제다.
- `^`와 `$`는 한 출력 행을 대상으로 설계했다. SecureCRT에서 자동 줄바꿈·화면 너비·스크롤백에 따른 동작을 검증한다.
- 상태를 엄격하게 구분하려면 일부 규칙은 행 앞부분까지 강조한다. 이는 문맥 없이 상태 단어만 강조할 때의 오탐을 줄이기 위한 선택이다.
- 공통 목록에는 syslog와 구조화된 상태 규칙을 넣는다. 임의 설명문에 같은 문자열이 포함되는 오탐을 완전히 제거할 수 없는 필드 규칙은 확장 목록으로 분리한다.

## 2. 색상

빨강 `#FF6B6B`: 긴급·명확한 실패, 주황 `#FFAA66`: 상태 이상 확인, 노랑 `#FFD866`: 누적 오류·주의, 초록 `#8BD49C`: 해당 상태 정상, 하늘색 `#78C8FF`: 정보·Active 역할, 보라 `#C4A7E7`: Standby 역할·deny, 회색 `#9AA0A6`: 관리적 비활성·0, 기본색 `#D4D4D4`: 일반 출력. 어두운 배경 기준이다.

## 3. Syslog 기본 규칙

| ID | 정규식 | 색상 |
|---|---|---|
| LOG-02 | `%ASA-[012]-[0-9]{6}:` | 빨강·굵게 |
| LOG-3 | `%ASA-3-[0-9]{6}:` | 주황 |
| LOG-4 | `%ASA-4-[0-9]{6}:` | 노랑 |
| LOG-5 | `%ASA-5-[0-9]{6}:` | 하늘색 |
| LOG-7 | `%ASA-7-[0-9]{6}:` | 회색 |

Severity 6은 기본색. 타임스탬프를 허용하도록 줄 시작 앵커를 쓰지 않는다. Severity 0은 예약이며 ASA가 생성하지 않는 수준이다. 본문 전체나 일반 error/deny 단어는 강조하지 않는다. [Cisco Logging](https://www.cisco.com/c/en/us/td/docs/security/asa/asa912/asdm712/general/asdm-712-general-config/monitor-syslog.html)

## 4. 인터페이스

공식 예제의 상세 출력은 문장형, 요약 출력은 상태·프로토콜 열 형태다. 요약에는 `admin down`이 사용되며, ASAv는 관리적 비활성에서도 Protocol이 up일 수 있다. 그래서 끝의 up만 보고 초록으로 표시하지 않는다. [Cisco 명령 참조](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/show-f-to-show-ipu-commands.html)

상세 출력에서는 아래 세 규칙 중 해당하는 상태 행만 일치한다.

```text
# IF-D-OK — 초록
^[ \t]*Interface[ \t]+[^\r\n]*,[ \t]+is up,[ \t]+line protocol is up[ \t]*$
# IF-D-ADMIN — 회색
^[ \t]*Interface[ \t]+[^\r\n]*,[ \t]+is administratively down,[ \t]+line protocol is (up|down)[ \t]*$
# IF-D-CHECK — 주황
^[ \t]*Interface[ \t]+[^\r\n]*,[ \t]+is (down,[ \t]+line protocol is (up|down)|up,[ \t]+line protocol is down)[ \t]*$
```

요약 출력은 장비별 인터페이스 이름을 고정하지 않고 열 수와 상태를 제한한다. 내부 인터페이스·서브인터페이스·mapped name을 수용한다. Protocol 열이 생략된 변형은 초록으로 추측하지 않고 미매칭으로 남긴다.

```text
# IF-B-OK — 초록
^[ \t]*[^ \t]+[ \t]+[^ \t]+[ \t]+(YES|NO|unassociated)[ \t]+[^ \t]+[ \t]+up[ \t]+up[ \t]*$
# IF-B-ADMIN — 회색
^[ \t]*[^ \t]+[ \t]+[^ \t]+[ \t]+(YES|NO|unassociated)[ \t]+[^ \t]+[ \t]+(admin|administratively) down[ \t]+(up|down)[ \t]*$
# IF-B-CHECK — 주황
^[ \t]*[^ \t]+[ \t]+[^ \t]+[ \t]+(YES|NO|unassociated)[ \t]+[^ \t]+[ \t]+(down[ \t]+(up|down)|up[ \t]+down)[ \t]*$
```

확장 카운터 규칙: `(^|[ ,\t])[1-9][0-9]*[ \t]+(input errors|output errors|CRC|overrun|ignored|L2 decode drops)([ ,\t]|$)` → 노랑. 숫자 일부를 잡지 않도록 앞 경계를 둔다. 0은 기본색. 누적값이므로 현재 장애로 단정하지 않는다. 동일 형태의 설명문도 매칭될 수 있어 확장 목록에서 사용한다.

## 5. HA

현재 host 상태를 한 줄형과 분리형으로 나누어 잡는다. Primary/Secondary는 유닛 식별이고 Active/Standby는 현재 역할이므로 서로 혼동하지 않는다. Cisco 공식 show failover state 예제처럼 host 행과 상태 행이 분리된 출력도 지원한다. Last Failure Reason은 조건이 해소된 뒤에도 남는 과거 이력이므로 단독 빨강 규칙을 만들지 않는다. [Cisco failover 출력](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/show-f-to-show-ipu-commands.html)

```text
# HA-ACTIVE-ONE-LINE — 하늘색
^[ \t]*(This|Other) host:[ \t]+(Primary|Secondary)[ \t]+-[ \t]+Active[ \t]*$
# HA-STANDBY-ONE-LINE — 보라
^[ \t]*(This|Other) host:[ \t]+(Primary|Secondary)[ \t]+-[ \t]+Standby Ready[ \t]*$
# HA-ROLE-SPLIT — 하늘색
^[ \t]*(This|Other) host[ \t]*-[ \t]+(Primary|Secondary)[ \t]*$
# HA-ACTIVE-SPLIT — 초록
^[ \t]+Active[ \t]+None[ \t]*$
# HA-STANDBY-SPLIT — 보라
^[ \t]+Standby Ready[ \t]+(None|Comm Failure)([ \t]+.*)?$
# HA-GROUP-FAILED — 빨강, 공식 show failover state 형식 확인
^[ \t]*Group[ \t]+[0-9]+[ \t]+(State:[ \t]+)?Failed([ \t]+.*)?$
```

Active/Active의 Group n State 행은 별도 규칙으로 `^[ \t]*Group[ \t]+[0-9]+[ \t]+State:[ \t]+Active[ \t]*$`(하늘색), 끝을 Standby Ready로 바꾼 규칙(보라)을 사용한다. Cisco 공식 예제에는 Group 1 Failed Backplane Failure처럼 현재 실패를 나타내는 행도 있으므로 Group 상태 Failed만 빨강으로 추가했다. 일반 인터페이스의 Failed는 Normal/Waiting/Not-Monitored 문맥을 확인한 뒤 별도 추가한다. [Cisco Active/Active 예제](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/show-f-to-show-ipu-commands.html)

인터페이스별 HA 상태는 `Failed`와 `Normal (Waiting)`만 각각 빨강·주황으로 추가했다. `Normal (Monitored)`·`Not-Monitored`는 정상/장애를 추측하지 않고 기본색으로 남긴다. `Sync Done`과 `Sync Skipped`는 모두 초록이다. Failover Off 또한 단독 장비에서는 정상일 수 있어 자동 장애색을 배정하지 않는다.

## 6. VPN

| 대상 | 정규식 | 처리 |
|---|---|---|
| IKEv1 상태 필드 | `State[ \t]*:[ \t]*MM_ACTIVE([ \t]|$)` | 초록, 확장 필드 규칙 |
| IKEv2 세션 헤더 | `^Session-id:[0-9]+,[ \t]+Status:UP-ACTIVE,` | 초록 |
| IKEv2 테이블 | `^[ \t]*[0-9]+[ \t]+[^ \t]+/[0-9]+[ \t]+[^ \t]+/[0-9]+[ \t]+READY[ \t]+(INITIATOR|RESPONDER)[ \t]*$` | 초록 |
| IPsec 오류 | `#(send|recv) errors[:]?[ \t]*[1-9][0-9]*([, \t]|$)` | 노랑 |
| IPsec 트래픽 | `#pkts (encaps|decaps):[ \t]*[0-9]+([, \t]|$)` | 하늘색 |
| VPN 세션 종류 | `^[ \t]*Session Type:[ \t]+[^\r\n]+$` | 하늘색 |
| VPN 송수신 필드 | `Bytes (Tx|Rx)[ \t]*:[ \t]*[0-9]+([ \t]|$)` | 하늘색, 확장 목록 |

IKEv1은 phase 1 상태만, IKEv2는 해당 SA 상태만 의미한다. 트래픽 성공은 양방향 카운터 변화 등으로 별도 확인한다. 세션 0개, 송수신 0, rekey 존재를 일괄 장애로 표시하지 않는다. 미확인 협상 상태명은 추측하여 추가하지 않는다.

근거: [ASA IKEv1 예제](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios/218432-configure-a-site-to-site-ipsec-ikev1-tun.html), [ASA IKEv2 예제](https://www.cisco.com/c/en/us/support/docs/security-vpn/ipsec-negotiation-ike-protocols/117337-config-asa-router-00.html), [ASA IPsec 예제](https://www.cisco.com/c/en/us/support/docs/security/asa-5500-x-series-next-generation-firewalls/115935-asa-ikev2-debugs.pdf), [VPN session 명령 참조](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/m_show_u-show_z.html). 같은 문서의 IOS Router 출력은 ASA 규칙 근거로 혼용하지 않는다.

## 7. ACL·라우팅

```text
# ACL-PERMIT — 하늘색, 행 시작부터 동작까지
^[ \t]*access-list[ \t]+[^ \t]+[ \t]+line[ \t]+[0-9]+[ \t]+(extended|standard)[ \t]+permit[ \t]
# ACL-DENY — 보라
^[ \t]*access-list[ \t]+[^ \t]+[ \t]+line[ \t]+[0-9]+[ \t]+(extended|standard)[ \t]+deny[ \t]
# ACL-HIT-ZERO — 회색
\(hitcnt=0\)
# ACL-HIT-POSITIVE — 하늘색
\(hitcnt=[1-9][0-9]*\)
# ROUTE-DEFAULT — 하늘색, 확인된 static default 형식
^[ \t]*S\*[ \t]+0\.0\.0\.0[ \t]+0\.0\.0\.0[ \t]+\[[0-9]+/[0-9]+\][ \t]+via[ \t]
```

remark 행은 동작 규칙에 매칭되지 않는다. hitcnt는 괄호 전체를 매칭하므로 10을 0으로 오인하지 않는다. ACL 확장 하위 행도 같은 문법이면 처리한다. IPv6 ACL, 동적 프로토콜의 default, CIDR 출력 변형은 별도 샘플 추가 전 미지원이다. 경로 부재는 존재하는 텍스트를 칠하는 정규식만으로 탐지할 수 없다.

근거: [ACL 공식 예제](https://www.cisco.com/c/ja_jp/td/docs/security/asa/asa-command-reference/S/cmdref3/s2.html), [route 공식 예제](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/m_show_p-show_r.html).

## 8. NAT·연결·리소스·장비 정보

아래는 정보 탐색용 확장 목록이며 성공/실패 판정을 하지 않는다.

| 대상 | 정규식 | 색상 |
|---|---|---|
| NAT 구획 | `^[ \t]*(Manual|Auto) NAT Policies \(Section [123]\)` | 하늘색 |
| NAT 카운터 | `(^|[ ,\t])(translate_hits|untranslate_hits)[ \t]*=[ \t]*[0-9]+([, \t]|$)` | 하늘색 |
| NAT 변환 시작 | `^[ \t]*(NAT|PAT) from[ \t]` | 하늘색 |
| 연결 종류 | `^[ \t]*(TCP|UDP|ICMP)[ \t]+(?!conn(?:[ \t]|$))` | 하늘색 |
| CPU 필드 | `(CPU utilization for 5 seconds[ \t]*=|1 minute:|5 minutes:)[ \t]*[0-9]+%` | 하늘색 |
| 메모리 | `^[ \t]*(Free|Used|Total) memory:[ \t]+[0-9]+[ \t]+bytes[ \t]+\([0-9]+%\)` | 하늘색 |
| ASA 버전 | `^Cisco Adaptive Security Appliance Software Version[ \t]+[^ \t]+` | 하늘색 |
| 제품 ID | `^[ \t]*PID:[ \t]*[^,\r\n]+` | 하늘색 |

NAT 역방향 hit는 실패 카운터가 아니다. conn flag의 U/I/O 등을 단독 매칭하지 않는다. 2026-09-15 실제 SecureCRT 화면에서 `show failover` 통계의 `TCP conn`과 `UDP conn`이 연결 종류 규칙에 걸리는 오탐을 확인하여, 바로 뒤 토큰이 `conn`인 경우만 제외했다. 재설치 후 후속 화면에서 두 통계 토큰은 기본색으로 복원되고 실제 `show xlate`의 `TCP PAT from ...` 강조는 유지되는 것을 확인했다. CPU/메모리는 초기 임계치를 임의 설정하지 않고 수치만 강조한다. 이후 임계치를 정해도 정규식은 지속 시간·증가 추세를 계산하지 못한다. 메모리 Total의 100%를 자원 고갈로 오인하는 전역 퍼센트 규칙은 금지한다.

근거: [NAT·xlate·conn 예제](https://www.cisco.com/c/en/us/support/docs/ip/network-address-translation-nat/118958-configure-asa-00.html), [CPU·메모리 예제](https://www.cisco.com/c/en/us/support/docs/security/asa-5500-x-series-next-generation-firewalls/113185-asaperformance.html), [version](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/m_show_u-show_z.html), [inventory](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/S/asa-command-ref-S/show-f-to-show-ipu-commands.html).

show running-config는 1차에 syslog/상태 규칙과의 오탐 검증 대상으로 둔다. 구조 강조를 넣을 경우 `^[ \t]*(interface|object network|object-group network|object-group service)[ \t]+[^ \t]+[ \t]*$`를 하늘색으로 쓰는 후보를 별도 검증한다. 이는 구성 문법 기반 후보이며 이번 조사에서 모든 설정 변형을 확정한 규칙은 아니다. no/shutdown/deny 전체를 경고색으로 칠하지 않는다.

## 9. 검증 및 배포

1. 공통 목록과 확장 목록을 구분하여 저장한다. 목록에는 규칙 ID·색상·정규식·출처·검증 상태를 기록한다.
2. 공식 예제에서 장비 주소·수치를 바꾼 재현 샘플을 구성한다. 실제 장애 로그로 오해하지 않도록 합성 샘플임을 표시한다.
3. 정상/관리적 비활성/down 상태, 공백·탭, 들여쓰기, 0/1/10/100, 설명문·remark, 과거 HA 이력을 교차 검증한다.
4. 정규식 엔진의 오프라인 테스트와 SecureCRT 실제 화면 검증을 분리한다. 전자가 통과해도 후자를 통과했다고 보고하지 않는다.
5. SecureCRT에서는 정규식 활성화, phrase/substring 매칭, 대소문자 설정, 행 앵커, 경계 소비로 인한 인접 필드 누락, 줄바꿈, 색상 충돌, 빠른 출력 시 가독성을 확인한다.
6. 구체적 상태 규칙을 먼저 배치하되 순서에 의존한 덮어쓰기 설계를 하지 않는다. 충돌 시 패턴 범위를 좁히거나 확장 규칙을 제거한다.
7. 대표 세션에만 시범 적용한다. 기존 목록을 보관하며 목록 선택 복원으로 롤백한다. ASA logging 수준 변경은 포함하지 않는다.

완료 기준: 준비된 양성·음성 샘플이 의도대로 매칭되고, 실제 SecureCRT에서 표시·줄바꿈·반응성을 확인한 후 배포한다. 현재는 INI 초안 생성과 오프라인 형식·정규식 검증까지 완료했으며, SecureCRT UI/실장비 검증은 남아 있다.

## 10. 추가 운영 상태 규칙

2026-09-15 Cisco 공식 명령 출력으로 다음 규칙을 추가했다. Core는 현재 상태가 명확하고 행 문맥이 충분한 항목만, Extended는 누적·진단용 카운터만 넣는다.

| 계열 | 목록 | 표시 | 범위 |
|---|---|---|---|
| ASAv 라이선스 | Core | Unlicensed/Noncompliant/No active entitlement 빨강, Compliant 초록 | `show version`, 라이선스 경고 |
| SLA Track | Core | UP·OK 초록, DOWN 빨강 | `show track` |
| AAA | Core | ACTIVE 초록, FAILED 빨강 | `show aaa-server` |
| 운영 제어·물리 | Core | 예약 reload 주황, `Failure Detected`/`Power Problem` 빨강 | `show reload`, `show environment`; ASAv에는 물리 센서 출력이 없을 수 있음 |
| 서비스 정책·ASP | Extended | 0이 아닌 drop 노랑 | `show service-policy`, 대표 `show asp drop` 원인. ACL 차단도 포함될 수 있어 빨강 금지 |
| 자원·OSPF·인증서 | Extended | resource Denied 노랑, OSPF FULL 초록/불완전 주황, 등록 보류 주황 | `show resource usage`, `show ospf neighbor`, `show crypto ca certificates` |

`show failover state`의 Last Failure Reason은 과거 실패가 해소돼도 남을 수 있으므로 일반 `Failure` 단어 규칙을 만들지 않는다. `show blocks`는 숫자 열만인 행이 많아 Line Mode에서 명령 문맥을 보장할 수 없으므로 제외했다. BGP 요약의 열 배치는 버전·출력 폭에 민감하여 실제 ASA 샘플을 확보한 뒤 별도 규칙으로 다룬다. 인증서 날짜·CPU/메모리 비율·누적 drop은 시간 경과나 임계치를 정규식이 계산할 수 없으므로 현재 장애색을 주지 않는다.

추가 항목은 `tests/AsaKeywordLists.Tests.ps1`의 62개 양성/음성 사례에서 V2 형식·선언값·Core/Extended 동기화·정규식 컴파일과 함께 검사한다. 현재 ASAv 9.8(1) 랩에는 SLA·AAA·OSPF·물리 센서가 구성되어 있지 않으므로 이 항목의 SecureCRT 네이티브 화면 검증은 별도 상태로 유지한다.

INI 배포 시 [VanDyke 공식 가져오기 절차](https://www.vandyke.com/support/scripting/scripting-examples/import-keyword-highlighting-ini-files.html)를 따른다. 설정 경로는 OS별 추측 경로 대신 SecureCRT의 Configuration Paths에서 확인한다.
