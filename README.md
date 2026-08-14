# SecureCRT Cisco IOL 키워드 하이라이트

`PNET-Cisco-Dark.ini`는 Cisco IOL 장비의 CLI 출력에서 장애 상태, 인터페이스 상태, STP, EtherChannel, HSRP, OSPF 및 주요 식별자를 빠르게 찾을 수 있도록 만든 SecureCRT 키워드 하이라이트 설정입니다. 어두운 터미널 배경을 염두에 둔 색상 구성이지만, 실제 가독성은 SecureCRT의 터미널 테마와 사용자 설정에 따라 달라질 수 있습니다.

이 설정은 다음 특징을 가집니다.

- 대소문자를 구분합니다. 파일의 `D:"Match Case"=00000001` 설정에 해당합니다.
- SecureCRT의 `Keyword List V2` 형식을 사용합니다.
- 정규식 패턴으로 상태 문자열, 숫자, IP 주소, 인터페이스 이름, 프롬프트 등을 하이라이트합니다.
- 키워드 목록 자체에 설치 스크립트, 자동화 명령, 외부 의존성은 포함하지 않습니다.

## 제공 파일

- `PNET-Cisco-Dark.ini`: SecureCRT용 키워드 하이라이트 목록
- `README.md`: 설정의 범위, 적용 시 주의사항 및 그룹/색상 설명

현재 저장소에는 별도의 설치 스크립트나 라이선스 문서가 없습니다. 이 파일은 Cisco 장비에 명령을 실행하거나 설정을 변경하지 않으며, 터미널에 표시되는 텍스트의 시각적 강조만 담당합니다.

## SecureCRT에서 가져오고 적용하기

SecureCRT의 버전, 운영체제, 설정 저장 방식에 따라 메뉴 이름과 파일을 불러오는 위치가 다를 수 있습니다. 다음은 특정 버전에 종속되지 않는 일반적인 흐름입니다.

1. 적용 전에 현재 SecureCRT 세션/글로벌 설정을 백업합니다. 특히 기존 키워드 목록을 덮어쓰지 않도록 목록 이름과 설정 파일을 보관합니다.
2. SecureCRT의 전역 옵션에서 설정 폴더 위치를 확인합니다. 일반적으로 `Options` 또는 `Global Options`의 설정 경로(Configuration Folder) 항목에서 확인할 수 있습니다.
3. SecureCRT가 종료된 상태에서 설정 폴더의 `Keywords` 하위 폴더에 `PNET-Cisco-Dark.ini` 사본을 넣습니다. `Keywords` 폴더가 없을 때만 생성하고, 기존 파일을 덮어쓰기 전에 별도 백업을 보관합니다.
4. 세션 옵션의 `Terminal` 아래 `Keyword Highlighting`과 유사한 화면에서 등록된 목록을 선택하고 키워드 하이라이트를 활성화합니다. 해당 버전에 `Import`/`Load` 기능이 있다면 그 기능으로 등록해도 됩니다.
5. 테스트 장비나 저장된 CLI 출력으로 먼저 확인합니다. 예를 들어 `show interfaces`, `show spanning-tree`, `show etherchannel summary`, `show standby`, `show ip ospf neighbor` 등의 출력에서 의도한 항목이 보이는지 점검합니다.

SecureCRT 설정 폴더와 `Keywords` 하위 폴더의 실제 위치는 버전·운영체제·프로필 구성에 따라 달라질 수 있습니다. 위의 절차는 일반적인 수동 등록 방법이며, 특정 OS의 절대 경로를 가정하지 않습니다. 자세한 경로 확인 및 수동 등록 예시는 [VanDyke의 키워드 INI 가져오기 안내](https://www.vandyke.com/support/scripting/scripting-examples/import-keyword-highlighting-ini-files.html)를 참고하십시오. 기존 설정 파일을 교체해야 하는 경우에는 SecureCRT를 종료하고 백업과 복원 절차를 먼저 준비하십시오.

> 참고: 위의 `Session Options`, `Global Options`, `Terminal`, `Keyword Highlighting`, `Import` 등의 메뉴 명칭은 SecureCRT 버전에 따라 다를 수 있습니다. 메뉴가 보이지 않는다면 해당 버전의 키워드 하이라이트/키워드 목록 설정 화면을 기준으로 찾으십시오.

## 색상 코드

INI의 색상값은 일반적인 SecureCRT/Windows `COLORREF` 저장 방식인 `0x00BBGGRR`로 해석해 RGB 색상으로 병기했습니다. `설정값`은 파일에 실제로 들어 있는 8자리 값이며, `RGB`는 화면 색을 이해하기 위한 `#RRGGBB` 표기입니다. 터미널 테마, 글꼴, 선택 영역 및 SecureCRT의 렌더링 설정에 따라 체감 색상은 달라질 수 있습니다.

| 설정값 | RGB | 대표 색상 | 이 설정에서의 주요 용도 |
|---|---|---|---|
| `00FFFFFF` | `#FFFFFF` | 흰색 | 그룹 제목 |
| `000000FF` | `#FF0000` | 빨강 | 오류, 실패, 비활성/다운 상태 |
| `00FF00FF` | `#FF00FF` | 자홍 | 불일치, Guard 관련 상태, 일부 중요 경고 |
| `0032CD32` | `#32CD32` | 라임 그린 | 정상, up, connected, forwarding, active |
| `00FFFF00` | `#00FFFF` | 시안 | Root 관련 항목, 일부 상태·주소 강조 |
| `00FACE87` | `#87CEFA` | 라이트 스카이 블루 | 보조 상태, 인터페이스 모드, 파라미터 |
| `0000A5FF` | `#FFA500` | 주황 | 대체/비정상 경로, 일부 EtherChannel·OSPF 상태 |
| `0000FFFF` | `#FFFF00` | 노랑 | 대기/차단/중간 단계 등 주의가 필요한 상태 |
| `00C0C0C0` | `#C0C0C0` | 은색 | 중립적이거나 초기화된 상태 |
| `00B469FF` | `#FF69B4` | 핫 핑크 | 프로토콜·기능 이름, LSDB/OSPF 식별자 |
| `00EE82EE` | `#EE82EE` | 바이올렛 | 인스턴스·그룹·LSA 유형 등 분류 정보 |
| `0000D7FF` | `#FFD700` | 골드 | OSPF cost/metric/reference bandwidth |

색상은 위험도를 엄밀하게 표현하는 표준이 아니라 출력 탐색을 위한 시각적 분류입니다. 예를 들어 같은 색상이 여러 그룹에서 서로 다른 종류의 정보에 사용될 수 있으므로, 색상만으로 장비 상태를 판정하지 말고 원문 출력과 장비의 실제 상태를 함께 확인해야 합니다.

## 주요 하이라이트 그룹

그룹 제목은 INI에서 `[*]`로 시작하는 항목으로 구분됩니다.

| 그룹 | 강조 대상 |
|---|---|
| `CRITICAL_ERRORS_AND_DOWN_STATES` | `administratively down`, `err-disabled`, 불일치, 실패/오류, shutdown, down 등 장애·다운 상태 |
| `GOOD_AND_INTERFACE_STATES` | up, connected, enabled, permit, success, passed 및 `down->up` 등 정상·회복 상태 |
| `STP_RAPID_PVST_MST` | Root/Bridge ID, Root Port, 역할(Desg/Altn/Back), FWD/BLK, PVST/RSTP/MST, PortFast·Guard·inconsistent |
| `ETHERCHANNEL` | `(P)`, `(I)`, `(s)`, `(D)`, `(H)`, `(w)`, `(u)`, SU/RU/SD/RD, stand-alone, bundled, LACP/PAgP |
| `HSRP` | Active/Standby/Speak/Listen/Init/Learn, 가상 IP, 우선순위, 그룹, preemption |
| `OSPF_PROCESS_AREA_AND_IDS` | OSPF 프로세스·Process ID, Router ID, Area, ABR/ASBR, stub/NSSA |
| `OSPF_COST_METRIC_REFERENCE_BW` | cost, metric, reference bandwidth, OSPF 경로 비용, BW, MTU |
| `OSPF_ROUTE_TYPES` | O, O IA, O E1/E2, O N1/N2 및 metric type |
| `OSPF_NETWORK_TYPE_AND_DR_BDR` | 네트워크 유형, DR/BDR/DROTHER, OSPF priority |
| `OSPF_NEIGHBOR_STATES` | FULL, 2WAY, EXSTART, EXCHANGE, LOADING, ATTEMPT, 인접성/Neighbor Count |
| `OSPF_TIMERS` | Hello, Dead, Wait, Retransmit, Dead Time, Transmit Delay |
| `OSPF_LSDB_AND_LSA` | LSDB/LSA, Router·Network·Summary·External/NSSA LSA, Link State ID, sequence/checksum |
| `OSPF_SPF_AND_CONFIG` | SPF 실행·타이머, `ip ospf ... area`, network area, passive-interface, default-information, area 설정 |
| `VLAN_TRUNK_AND_LAYER2` | trunk/access, VLAN/Vl 번호, native VLAN, dot1q/802.1Q |
| `INTERFACES_ADDRESSES_AND_IDENTIFIERS` | 장문·축약 인터페이스 이름, IPv4 주소/프리픽스, Cisco dotted MAC 및 콜론 형식 MAC |
| `ROUTING_PROTOCOLS_AND_MISC` | EIGRP/BGP/RIP/HSRP/OSPF/MST/PVST/STP, route-map/prefix-list/ACL, SSH/Telnet/TFTP/NTP/SNMP, 표 헤더 |
| `PROMPTS` | 설정 모드 프롬프트(`#`), privileged EXEC 프롬프트(`#`), 사용자 EXEC 프롬프트(`>`) |

## 정규식 및 매칭 케이스 주의사항

- `Match Case=1`이므로 `up`, `UP`, `Up`은 서로 다르게 취급될 수 있습니다. 파일은 자주 나타나는 대문자/소문자 변형을 일부 `(?:...)` 대안으로 직접 열거하지만, 모든 혼합형을 포함한다는 보장은 없습니다.
- `\b`는 단어 경계입니다. 단어 일부가 다른 문자열에 포함되는 오탐을 줄이는 데 사용되지만, 장비 출력의 구두점이나 축약 표기에 따라 기대와 다르게 매칭될 수 있습니다.
- `(?:a|b)`는 여러 문자열 중 하나를, `[0-9]+`는 하나 이상의 숫자를 의미합니다. IPv4 패턴은 형식과 자리 수를 확인할 뿐 각 옥텟이 0~255인지까지 검증하지 않습니다.
- `^`로 시작하는 패턴은 줄의 시작을 요구합니다. OSPF 경로 유형과 프롬프트는 출력이 줄의 시작에 놓이는 형식을 전제로 하므로, 줄 앞 공백이나 장비별 출력 형식이 다르면 매칭되지 않을 수 있습니다.
- 프롬프트 패턴은 영문자·숫자·`_ . : -`로 구성된 호스트 이름을 전제로 합니다. 다른 문자나 커스텀 프롬프트를 사용하는 경우 별도 패턴이 필요합니다.
- 같은 텍스트가 여러 그룹의 패턴에 걸릴 수 있습니다. 어떤 색상이 최종적으로 보이는지는 SecureCRT 버전과 키워드 목록 처리 순서에 영향을 받을 수 있으므로, 겹치는 패턴을 추가·수정한 뒤 실제 출력에서 확인하십시오.

## 커스터마이징 및 안전한 사용

- 원본을 복사해 별도 목록으로 보관한 뒤 색상이나 패턴을 수정하십시오. 기존 목록을 직접 덮어쓰면 되돌리기 어렵습니다.
- 먼저 색상만 바꾸고, 그 다음 필요한 키워드나 정규식을 작은 단위로 추가하는 방식이 안전합니다. 패턴을 너무 일반적으로 만들면 CLI 출력 대부분이 강조되어 오히려 가독성이 떨어질 수 있습니다.
- 장비별 호스트 이름, 인터페이스 명칭, VRF·IPv6·벤더별 상태 문자열을 추가할 때는 테스트 출력에서 오탐과 누락을 함께 확인하십시오.
- 하이라이트 색상은 관찰을 돕는 표시일 뿐입니다. 빨강/초록 여부만으로 장애 유무, 수렴 완료, 보안 상태 또는 변경 성공을 확정하지 마십시오.
- 운영 장비에 적용하기 전 비운영 세션이나 저장된 출력으로 확인하고, 세션 설정과 SecureCRT 전체 설정의 백업/복원 가능성을 확인하십시오.
- 이 설정은 명령을 자동 실행하지 않으므로, 장비에 명령을 붙여 넣거나 적용하는 작업과는 별개입니다. 변경 전후의 CLI 출력과 장비 로그를 정상적인 운영 절차에 따라 검토하십시오.

## 검증 방법

README 또는 INI를 자동으로 설치하는 스크립트는 포함되어 있지 않습니다. 다음과 같이 수동 검증할 수 있습니다.

1. SecureCRT에서 키워드 목록이 활성화된 테스트 세션을 엽니다.
2. 정상/장애 상태, STP, EtherChannel, HSRP, OSPF, VLAN/트렁크 및 프롬프트가 포함된 저장 출력 또는 테스트 장비 출력으로 확인합니다.
3. 대소문자, 줄 시작 위치, 축약 표기, IPv4/MAC/인터페이스 형식이 실제 패턴과 일치하는지 확인합니다.
4. 색상이 보이지 않거나 겹쳐 보이면 키워드 하이라이트 활성화 여부, 선택한 목록, 터미널 테마 및 해당 SecureCRT 버전의 정규식 지원 범위를 점검합니다.
