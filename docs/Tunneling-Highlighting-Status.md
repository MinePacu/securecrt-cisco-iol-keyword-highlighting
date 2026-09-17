# 터널 강조 상태

이 문서는 2026-09-17 구현 및 자동 검증 상태를 기록합니다. 프로젝트 작업 전에는 루트의 [AGENTS.md](../AGENTS.md)와 NAT 우선순위 관련 [NAT-Highlighting-Status.md](NAT-Highlighting-Status.md)를 함께 읽습니다.

## 구현 범위

운영 V2/V3 통합 목록에 다음 세 블록을 추가했습니다.

- `TUNNEL_GRE_INTERFACE`: `interface Tunnel`, tunnel source/destination/mode/key/VRF/protection, MTU/MSS/keepalive, `show interfaces Tunnel`의 up/down, GRE transport 및 중립 옵션.
- `DMVPN_NHRP`: DMVPN/NHRP/NBMA 용어, Hub/Spoke와 dynamic/static 분류, NHS·NBMA·표 머리글 및 `ip nhrp` 설정.
- `IKE_IPSEC_STATUS`: crypto session, IKEv1 `QM_IDLE ... ACTIVE`, IKEv2 `READY`, IPsec SA 상태·SPI·transform·패킷 및 오류 카운터.

IPv4 routed tunnel을 우선 대상으로 했습니다. `gre ipv6`와 `ipsec ipv6` 모드 문구는 지원하지만 IPv6 endpoint를 역할별로 칠하는 기능은 포함하지 않습니다. VXLAN, MPLS TE, L2TP, CAPWAP, pseudowire 및 ASA 원격접속 VPN은 현재 범위 밖입니다.

공식 출력 형식의 초기 근거는 Cisco의 [Implementing Tunnels](https://www.cisco.com/c/en/us/td/docs/routers/ios-xe/ip-routing/b-ip-routing/m_ir-impl-tun-xe.html), [DMVPN/NHRP 출력 예제](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_nhrp/configuration/xe-3s/nhrp-xe-3s-book/nhrp-switch-enhancemts-dmvpn.html), [IP Security VPN Monitoring](https://www.cisco.com/c/en/us/td/docs/routers/ios/config/17-x/sec-vpn/b-security-vpn/m_sec-ip-security-vpn-0.html)입니다. 실제 IOL 이미지의 출력 차이는 네이티브 검증 단계에서 별도로 확인해야 합니다.

## 우선순위와 색상

기존 `SHOW_ACCESS_LISTS` → `NAT_CONTEXT_GUARDS` → `SHOW_IP_NAT_TRANSLATIONS` → `BGP_SHOW_IP` 순서를 유지하고, 그 다음에 `ASA_FIREWALL_OPERATIONAL_STATES`, 세 터널 블록, 범용 오류/정상 상태 블록을 차례로 평가합니다.

- 기능·프로토콜: 핫 핑크
- 필드명: 라이트 스카이 블루
- 식별자·SPI·주소: 골드 또는 기존 인터페이스/주소색
- 유형·역할·transform: 바이올렛
- 정상: 초록
- 협상·불완전: 주황
- 명시적 실패 및 nonzero send/recv errors: 빨강
- `key disabled`, `Keepalive not set`, 0 errors, SA 없음: 은색

독립적인 소문자 `tunnel`, `active`, `state`, `peer`는 터널 규칙으로 강조하지 않습니다. 상태나 필드 구조가 확인되는 문맥만 사용합니다.

2026-09-17 사용자 화면에서 `show interface tunnel 1`의 `Key 0x64`와 `Keepalive set (1 sec), retries 3`가 기본색으로 남는 것을 확인했습니다. 대문자 `Key`는 같은 행의 sequencing 구조를 확인한 뒤 키 필드만 골드로, 대문자 `Keepalive set ... retries ...`는 전체 행을 하늘색으로 표시하는 규칙을 추가했습니다. 변경 후 네이티브 결과는 아직 확인하지 않았습니다.

ASA와 IOS가 공유하는 `interface ...`, `#pkts encaps/decaps`, nonzero `#send/#recv errors` 형식은 앞선 ASA 블록이 우선합니다. 통합 색상은 각각 ASA 정보색 `00ffc878`과 주의색 `0066d8ff`를 사용하며, 터널 회귀 검사도 이 우선순위를 확인합니다.

## NAT 보호

줄 끝 IPv4를 NAT 열로 해석하는 기존 Suffix 규칙보다 다음 사례를 먼저 보호합니다.

- tunnel source/destination와 crypto peer/endpoint
- NBMA address, NHS 및 `ip nhrp map`
- DMVPN `UP`, `DOWN`, `NHRP` 상태 표 행과 마지막 target network

DMVPN 표 행은 상태별로 행 전체를 초록·빨강·주황으로 처리합니다. 이는 target network만 별도 보호하기 위해 복잡한 가변 lookbehind를 도입하지 않고, 이미 실패했던 위치 기반 접근을 반복하지 않기 위한 선택입니다.

## 자동 검증 결과

다음 검사는 통과했습니다.

```powershell
pwsh -NoProfile -File tests/KeywordListVersion.Tests.ps1
pwsh -NoProfile -File tests/NatTranslations.Tests.ps1
pwsh -NoProfile -File tests/TunnelingHighlights.Tests.ps1
```

`TunnelingHighlights.Tests.ps1`은 두 운영 목록의 17개 GRE/인터페이스 규칙, 9개 DMVPN/NHRP 규칙, 23개 IKE/IPsec 규칙을 확인합니다. Git/PCRE 문법 검사와 .NET 구간·첫 우선 규칙 모델은 SecureCRT 렌더러 검증을 대체하지 않습니다.

`tests/KeywordIni.Tests.ps1`은 터널 변경 전후 모두 기존 BGP `i` 패턴 기대값 불일치에서 중단됩니다. 터널 구현에서는 해당 BGP 규칙을 변경하지 않았습니다.

추가 전체 검사에서는 터널 작업이 수정하지 않은 `DefaultIni.Tests.ps1`이 읽기 전용 `$IsWindows` 변수 충돌에서, `InstallerUpdate.Tests.ps1`이 설치기의 in-progress flag 문자열 기대 불일치에서 각각 중단됐습니다. 두 실패는 터널 전용 검사 결과와 분리해 기록하며 이 작업에서 수정하지 않았습니다.

## 실제 화면 검증 대기

Key/Keepalive 규칙을 포함한 489행 통합 V3 키워드 파일은 2026-09-17 `-SkipUpdate`로 재설치했습니다. 원본/설치본 SHA256 `47D44956F09F3B316EC647D90D34952338B3E89CBF63418E4F2080DF05C83B5A` 일치, 선언값 `000001E9`, 두 신규 규칙 포함 및 직전 487행 설치본 백업 생성을 확인했습니다. 변경 후 화면 검증은 아직 남아 있습니다. 지원되는 명령만 선택해 다음 순서로 확인합니다.

```text
show running-config interface Tunnel0
show interfaces Tunnel0
show ip interface brief | include Tunnel
show dmvpn
show ip nhrp
show crypto session detail
show crypto isakmp sa
show crypto ikev2 sa detailed
show crypto ipsec sa
```

화면에서는 다음을 구분해 기록합니다.

1. Tunnel 인터페이스 up/up와 down 조합.
2. source/destination 주소가 NAT 보라색으로 오인되지 않는지.
3. `key disabled`, `Keepalive not set`, 0 errors가 빨강이 아닌지.
4. DMVPN UP/DOWN/NHRP 행과 NBMA/NHS 주소.
5. IKE/IPsec 정상·협상·실패 상태 및 packet/error 카운터.
6. 기존 NAT, ACL, 라우팅 화면 강조가 유지되는지.

화면 결과를 확보하면 이 문서와 `AGENTS.md`, 관련 README의 검증 상태를 함께 갱신합니다.
