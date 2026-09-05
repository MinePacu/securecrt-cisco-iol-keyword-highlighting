# NAT 통합 강조 상태

프로젝트 작업 지침은 루트의 [AGENTS.md](../AGENTS.md)를 먼저 읽습니다. 아래 상태는 2026-09-05 사용자 통합 화면 검증까지 반영했습니다.

## 사용자 선택과 변경
사용자는 통합 유지 방식을 선택했습니다. 기본 파일명과 설치 대상은 PNET-Cisco-Dark-V3.ini 그대로이며 V2도 동기화했습니다. 전체 행 수는 368개입니다. 선택형 PNET-Cisco-NAT-V3.ini는 비교용으로 남아 있고 선택/설치를 요구하지 않습니다.

실패했던 DEFINE 및 위치 lookbehind 패턴 대신 화면에서 성공한 Suffix 주소 규칙을 넣었습니다. Pro는 통합 스타일인 흰색으로 복원했고, 네 주소색과 프로토콜색은 그대로입니다. ---는 모든 NAT 주소 규칙 다음에 있습니다.

## 우선순위 보호
기존 SHOW_ACCESS_LISTS 블록은 내용 그대로 맨 앞으로 이동했습니다. 다음 NAT_CONTEXT_GUARDS 블록에서 host/network/to/is/from/via/neighbor/Originator:/list: 뒤와 쉼표 뒤 IPv4를 골드로 먼저 강조합니다. 공백도 매칭 범위에 포함될 수 있지만 라벨 자체는 칠하지 않습니다. 그 다음 NAT, 그 뒤 기존 나머지 블록이 이어집니다.

자동 우선순위 모델에서 ACL permit/deny, gateway, Connected to, via, Cluster list의 대표 IP 6개가 NAT 색보다 우선 보호됩니다. 보호 규칙은 NAT 정상 샘플을 매칭하지 않습니다. 후속 사용자 통합 화면에서는 ACL permit/deny와 gateway·표시된 경로 IP의 기존 색상 유지까지 확인했습니다. Connected to 및 Cluster list 등의 모든 문맥이 네이티브 검증된 것은 아닙니다.

## 검증된 것과 남은 것
- 사용자 화면: 별도 Suffix 목록에서 ICMP 및 정적 NAT 성공, ---를 뒤로 옮긴 효과 확인.
- 후속 통합 V3 화면: ICMP 네 주소·식별자 및 정적 NAT 두 주소의 의도한 색상 확인. 프롬프트 노랑, Invalid 빨강 유지.
- 후속 ACL/라우팅 화면: Standard/Extended ACL 제목 흰색, permit 행 전체 초록, deny 행 전체 빨강. Gateway의 두 IP와 화면에 보인 정적/connected/local 경로의 기존 강조 유지, NAT 보라색 오탐 없음.
- 자동: NAT 정상 샘플 70개 강조 구간과 후보 시작 위치, 대표 문맥 보호 6개, BGP/ACL 회귀, V2/V3 행 수/동기화.
- 자동 검사는 PCRE/.NET 기반이며 네이티브 렌더러의 문맥 분할을 재현한다고 주장하지 않습니다.
- 통합 NAT/ACL/라우팅은 위 화면에 나온 사례에서 확인 완료. 전체 BGP, 임의의 출력, 모든 프로토콜까지 검증된 것은 아닙니다.

## 잔여 오탐
Suffix는 명령을 인식하지 않습니다. 예를 들어 보호하지 않은 'Peer 198.51.100.1'의 마지막 IP는 NAT Outside global 색이 될 수 있습니다. 불완전한 NAT 행은 필드 수가 달라져 잘못된 열색을 받을 수 있습니다. 보호 문맥을 추가한 것만으로 임의의 출력 전체가 안전해지지는 않습니다.

IPv6, verbose, 줄바꿈, 비정상 주소/포트는 지원을 보장하지 않습니다. 추가 오탐은 실제 원문과 함께 검증해 보호 규칙을 보완해야 합니다.

## 설치 및 확인
통합 수정본은 사용자 요청으로 재설치했고, 그 이후 화면에서 위 성공 사례를 확인했습니다. 향후 파일 수정이나 문서 편집 자체가 재설치를 의미하지는 않습니다.
설치 명령은 기존과 동일하게 로컬 수정본을 보존하는 -SkipUpdate를 사용합니다.

```powershell
pwsh -NoProfile -File .\Install-KeywordHighlight.ps1 -KeywordListVersion V3 -SkipUpdate
```

실행 중 연결을 종료하지 않았습니다. 재설치 후 현재 세션이 여전히 NAT 전용/진단 목록을 선택 중이면 키워드 목록을 PNET-Cisco-Dark-V3로 직접 선택해야 합니다. Default.ini 변경만으로 이미 열린 세션 선택을 바꾸지는 않습니다.

검증: tests/NatTranslations.Tests.ps1 및 tests/KeywordListVersion.Tests.ps1.
기존 tests/NatProbe4.Tests.ps1은 보호 없는 Suffix의 오탐을 재현하는 역사적 비교 검사입니다.
