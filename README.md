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
- `Install-KeywordHighlight.ps1`: Windows용 자동 설치/제거 PowerShell 스크립트. SecureCRT 설정 폴더를 자동으로 탐색하고, `Keywords` 폴더에 ini를 백업/설치한 뒤 `Sessions\Default.ini`의 기본 세션 하이라이트 옵션을 갱신합니다. `-Uninstall`로 키워드 파일과 스크립트가 만든 최신 `Default.ini` 백업을 복원하며, `-WhatIf`를 지원합니다.

현재 저장소에는 설치 스크립트(`Install-KeywordHighlight.ps1`)가 포함되어 있지만, 별도의 라이선스 문서는 없습니다. 이 저장소의 설정과 스크립트는 Cisco 장비에 명령을 실행하거나 장비 설정을 변경하지 않으며, 스크립트는 로컬 SecureCRT 설정 파일을 갱신합니다.

## SecureCRT에서 적용하기

설치 작업은 `Install-KeywordHighlight.ps1`을 한 번 실행하는 것으로 끝납니다. 이 실행이 `Keywords\PNET-Cisco-Dark.ini` 설치와 `Sessions\Default.ini`의 기본 세션 설정 적용을 함께 수행하므로, 설치 후 별도로 ini를 복사하거나 세션 옵션을 수동으로 입력할 필요가 없습니다.

1. 적용 전에 SecureCRT를 종료하고 현재 세션/글로벌 설정을 백업합니다. 스크립트도 덮어쓰기 직전에 키워드 파일과 `Sessions\Default.ini`를 각각 timestamp 백업하지만, 별도 보관본을 추가로 준비하는 것이 좋습니다.
2. SecureCRT의 전역 옵션에서 설정 폴더 위치를 확인합니다. 일반적으로 `Options` 또는 `Global Options`의 설정 경로(Configuration Folder) 항목에서 확인할 수 있습니다. 경로를 알고 있다면 아래 Windows 설치 명령의 `-ConfigPath`에 지정합니다.
3. 아래 단일 설치 명령을 실행합니다. 설정 폴더 자동 탐색을 사용하려면 `-ConfigPath`를 생략할 수 있습니다.
4. SecureCRT를 다시 시작하고 테스트 장비나 저장된 CLI 출력으로 실제 표시를 확인합니다. 예를 들어 `show interfaces`, `show spanning-tree`, `show etherchannel summary`, `show standby`, `show ip ospf neighbor` 등의 출력에서 의도한 항목이 보이는지 점검합니다.

SecureCRT 설정 폴더와 `Keywords` 하위 폴더의 실제 위치는 버전·운영체제·프로필 구성에 따라 달라질 수 있습니다. `-ConfigPath`에는 `Sessions\Default.ini`가 들어 있는 설정 폴더를 지정하십시오. 설치 후 SecureCRT 메뉴에서 설정을 확인할 때 메뉴 명칭은 버전에 따라 다를 수 있습니다.

## Windows 자동 설치 스크립트

`Install-KeywordHighlight.ps1`은 위 절차를 Windows 환경에서 자동화하는 PowerShell 스크립트입니다. 스크립트와 같은 폴더의 ini 파일 basename에서 키워드 세트 이름을 derive하므로, 현재 대상 이름은 `PNET-Cisco-Dark`입니다.

사용 예시(키워드 파일과 `Default.ini`를 함께 설치):

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config'
```

`-ConfigPath`를 생략하고 일반적인 SecureCRT 경로를 자동 탐색하게 하려면 다음과 같이 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1
```

설치 전 변경 계획만 확인하려면 다음과 같이 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -WhatIf
```

설치 제거와 최신 백업 복원은 다음과 같습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -Uninstall
```

주요 옵션은 다음과 같습니다.

- `-ConfigPath`: SecureCRT 설정 폴더 경로를 자동 탐색 대신 직접 지정합니다.
- `-Force`: SecureCRT 실행 중 경고 프롬프트와 백업 확인 프롬프트를 건너뜁니다.
- `-Uninstall`: 설치된 `PNET-Cisco-Dark.ini`를 제거/복원하고, 존재할 경우 스크립트가 만든 가장 최근 `Default.ini` 백업도 복원합니다. 백업이 없으면 현재 `Default.ini`를 임의로 지우지 않습니다.
- `-WhatIf`: 실제로 파일을 변경하지 않고 예정된 작업만 출력합니다.

설치 시 다음을 자동으로 적용합니다.

- `Config\Sessions\Default.ini`가 없으면 새로 만들지 않고 명확한 오류로 종료합니다.
- `S:"Color Scheme"=Birds of Paradise`
- `D:"Use Cursor Color"=00000001`, `D:"Cursor Color"=00FFFFFF`
- `S:"Keyword Set"=PNET-Cisco-Dark`
- `D:"Highlight Reverse Video"=00000000`, `D:"Highlight Bold"=00000001`, `D:"Highlight Color"=00000001`
- 기존 키워드 파일과 `Default.ini`를 덮어쓰기 전에 각각 timestamp 백업을 만들고, `-Uninstall`에서 최신 백업을 복원합니다.

이 스크립트는 다음을 수행하지 않습니다.

- 장비에 명령을 실행하지 않습니다.
- 네트워크나 레지스트리에 접근하지 않습니다.

스크립트 실행 전 SecureCRT를 종료하십시오. 실행 중이면 기존 확인/`-Force` 정책에 따라 경고하거나 계속 진행하지만, SecureCRT가 열린 설정을 다시 저장하면서 변경 내용을 덮어쓸 수 있습니다. 설치 후에는 SecureCRT를 다시 열어 테스트 출력으로 실제 표시를 확인해야 합니다.

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

`Install-KeywordHighlight.ps1`을 통해 키워드 파일과 기본 세션 옵션을 설치할 수 있지만, 실제 표시 여부는 다음과 같이 수동으로 검증해야 합니다.

1. SecureCRT를 다시 시작하고 기본 세션 또는 테스트 세션을 엽니다.
2. 정상/장애 상태, STP, EtherChannel, HSRP, OSPF, VLAN/트렁크 및 프롬프트가 포함된 저장 출력 또는 테스트 장비 출력으로 확인합니다.
3. 대소문자, 줄 시작 위치, 축약 표기, IPv4/MAC/인터페이스 형식이 실제 패턴과 일치하는지 확인합니다.
4. 색상이 보이지 않거나 겹쳐 보이면 `Default.ini`의 일곱 옵션, 선택된 키워드 세트, 터미널 테마 및 해당 SecureCRT 버전의 정규식 지원 범위를 점검합니다.

## 버전 관리

변경 기록의 기준 파일은 [`CHANGELOG.md`](CHANGELOG.md)입니다. 버전은 Semantic Versioning의 `MAJOR.MINOR.PATCH` 규칙을 따르며, 호환성이 깨지는 변경은 MAJOR, 하위 호환 기능 추가는 MINOR, 하위 호환 버그 수정이나 문서 수정은 PATCH를 올립니다.

변경 중인 항목은 `CHANGELOG.md`의 `Unreleased`에 기록하고, 릴리스할 때 해당 내용을 새 버전 번호와 날짜로 확정합니다. 릴리스마다 전용 커밋을 만들고 `vX.Y.Z` 형식의 Git 태그를 함께 생성하는 것을 권장합니다.
