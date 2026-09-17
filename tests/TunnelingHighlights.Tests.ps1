# Git/PCRE checks the literal INI patterns; .NET supplies exact span and
# first-covering-rule checks. Neither is a SecureCRT renderer emulator.
param([string]$GitPath = 'git')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixtureRelative = 'tests/fixtures/TunnelingOutputs.txt'
$fixture = Join-Path $root $fixtureRelative
$samples = [IO.File]::ReadAllLines($fixture)

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Rules([string]$Version) {
    $suffix = if ($Version -eq 'V3') { ',00000001' } else { '' }
    $file = Join-Path $root $(if ($Version -eq 'V3') { 'PNET-Cisco-Dark-V3.ini' } else { 'PNET-Cisco-Dark.ini' })
    $section = ''
    $rules = @()
    foreach ($line in [IO.File]::ReadAllLines($file)) {
        if ($line -match '^ "\[\*\](?<Name>[^"]+)",') {
            $section = $Matches.Name
            continue
        }
        if ($line -match ('^ "(?<Pattern>.*)",(?<Color>[0-9A-Fa-f]{8}),00000001' + [regex]::Escape($suffix) + '$')) {
            $rules += [pscustomobject]@{ Pattern = $Matches.Pattern; Color = $Matches.Color; Section = $section }
        }
    }
    return $rules
}

function Get-FirstCoveringRule($Rules, [string]$Text, [string]$Token) {
    $start = $Text.IndexOf($Token, [StringComparison]::Ordinal)
    Assert-That ($start -ge 0) "Token '$Token' is missing from fixture line: $Text"
    foreach ($rule in $Rules) {
        foreach ($match in [regex]::Matches($Text, $rule.Pattern)) {
            if ($match.Index -le $start -and $match.Index + $match.Length -ge $start + $Token.Length) {
                return $rule
            }
        }
    }
    return $null
}

$sectionCounts = @{
    TUNNEL_GRE_INTERFACE = 17
    DMVPN_NHRP = 9
    IKE_IPSEC_STATUS = 23
}

$cases = @(
    @{ Text = 'interface Tunnel0'; Token = 'interface'; Color = '00ffc878'; Section = 'ASA_FIREWALL_OPERATIONAL_STATES' }
    @{ Text = ' tunnel source GigabitEthernet0/0'; Token = 'tunnel source'; Color = '00B469FF'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = ' tunnel destination 192.0.2.2'; Token = '192.0.2.2'; Color = '0000D7FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = ' tunnel mode gre ip'; Token = 'gre ip'; Color = '00B469FF'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = 'Tunnel0 is up, line protocol is up'; Token = 'Tunnel0 is up, line protocol is up'; Color = '0032CD32'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = 'Tunnel1 is administratively down, line protocol is down'; Token = 'Tunnel1 is administratively down, line protocol is down'; Color = '000000FF'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = 'Tunnel2 is up, line protocol is down'; Token = 'Tunnel2 is up, line protocol is down'; Color = '000000FF'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = '  Keepalive not set'; Token = 'Keepalive not set'; Color = '00C0C0C0'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = '  Tunnel protocol/transport GRE/IP, key disabled, sequencing disabled'; Token = 'GRE/IP'; Color = '00B469FF'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = '  Tunnel protocol/transport GRE/IP, key disabled, sequencing disabled'; Token = 'key disabled'; Color = '00C0C0C0'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = '  Key 0x64, sequencing disabled'; Token = 'Key 0x64'; Color = '0000D7FF'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = '  Keepalive set (1 sec), retries 3'; Token = 'Keepalive set (1 sec), retries 3'; Color = '00FACE87'; Section = 'TUNNEL_GRE_INTERFACE' }
    @{ Text = ' ip nhrp nhs 10.0.0.1'; Token = '10.0.0.1'; Color = '0000D7FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = ' ip nhrp map 10.0.0.2 198.51.100.2'; Token = '198.51.100.2'; Color = '00B469FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = ' ip nhrp map multicast dynamic'; Token = 'ip nhrp map multicast dynamic'; Color = '00B469FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = 'Type:Spoke, Total NBMA Peers (v4/v6): 3'; Token = 'Spoke'; Color = '00EE82EE'; Section = 'DMVPN_NHRP' }
    @{ Text = ' 1 198.51.100.2 10.0.0.2 UP 00:10:00 D 10.20.0.0/24'; Token = '10.20.0.0/24'; Color = '0032CD32'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = ' 1 198.51.100.3 10.0.0.3 DOWN 00:00:12 I 10.30.0.0/24'; Token = '10.30.0.0/24'; Color = '000000FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = ' 1 198.51.100.4 10.0.0.4 NHRP 00:00:02 I 10.40.0.0/24'; Token = '10.40.0.0/24'; Color = '0000A5FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = '   Type: dynamic, Flags: router implicit'; Token = 'dynamic'; Color = '00EE82EE'; Section = 'DMVPN_NHRP' }
    @{ Text = '   NBMA address: 198.51.100.2'; Token = '198.51.100.2'; Color = '0000D7FF'; Section = 'NAT_CONTEXT_GUARDS' }
    @{ Text = 'Session status: UP-ACTIVE'; Token = 'UP-ACTIVE'; Color = '0032CD32'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = 'Session status: DOWN-NEGOTIATING'; Token = 'DOWN-NEGOTIATING'; Color = '0000A5FF'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '192.0.2.2       192.0.2.1       QM_IDLE           2003 ACTIVE'; Token = 'QM_IDLE           2003 ACTIVE'; Color = '0032CD32'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '2 192.0.2.1/500 192.0.2.2/500 (none)/(none) READY'; Token = 'READY'; Color = '0032CD32'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = 'There are no IKEv2 SAs'; Token = 'There are no'; Color = '00C0C0C0'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '  #pkts encaps: 989, #pkts encrypt: 989, #pkts digest: 989'; Token = '#pkts encaps: 989'; Color = '00ffc878'; Section = 'ASA_FIREWALL_OPERATIONAL_STATES' }
    @{ Text = '  #send errors 0, #recv errors 2'; Token = '#send errors 0'; Color = '00C0C0C0'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '  #send errors 0, #recv errors 2'; Token = '#recv errors 2'; Color = '0066d8ff'; Section = 'ASA_FIREWALL_OPERATIONAL_STATES' }
    @{ Text = '  current outbound spi: 0x9B592959'; Token = 'current outbound spi: 0x9B592959'; Color = '0000D7FF'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '  SA State: active'; Token = 'SA State: active'; Color = '0032CD32'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '  SA State: inactive'; Token = 'SA State: inactive'; Color = '000000FF'; Section = 'IKE_IPSEC_STATUS' }
    @{ Text = '  Status: ACTIVE(ACTIVE)'; Token = 'Status: ACTIVE(ACTIVE)'; Color = '0032CD32'; Section = 'IKE_IPSEC_STATUS' }
)

foreach ($version in @('V2', 'V3')) {
    $rules = @(Get-Rules $version)
    foreach ($entry in $sectionCounts.GetEnumerator()) {
        $actual = @($rules | Where-Object Section -eq $entry.Key).Count
        Assert-That ($actual -eq $entry.Value) "$version $($entry.Key) rule count changed: $actual"
    }

    $newRules = @($rules | Where-Object Section -in $sectionCounts.Keys)
    foreach ($rule in $newRules) {
        $null = [regex]::new($rule.Pattern)
        $null = & $GitPath -C $root -c core.quotepath=false grep --no-index --color=never -h -P -e $rule.Pattern -- $fixtureRelative
        Assert-That ($LASTEXITCODE -in @(0, 1)) "$version Git/PCRE failed to evaluate: $($rule.Pattern)"
    }

    foreach ($case in $cases) {
        Assert-That ($samples -contains $case.Text) "$version fixture is missing: $($case.Text)"
        $winner = Get-FirstCoveringRule $rules $case.Text $case.Token
        Assert-That ($null -ne $winner) "$version has no rule for '$($case.Token)' in '$($case.Text)'"
        Assert-That ($winner.Color -ceq $case.Color) "$version wrong color for '$($case.Token)': $($winner.Color)"
        Assert-That ($winner.Section -ceq $case.Section) "$version wrong priority section for '$($case.Token)': $($winner.Section)"
    }

    foreach ($text in @(
        'The active peer described a tunnel state',
        'Encryption Key 0x64, sequencing active',
        'Keepalive set for routing neighbors',
        'state = ACTIVE',
        '0 input errors, 0 CRC, 0 frame'
    )) {
        foreach ($rule in $newRules) {
            Assert-That (-not [regex]::IsMatch($text, $rule.Pattern)) "$version tunnel rule false positive in: $text"
        }
    }

    Write-Host "[PASS] $version GRE, tunnel-interface, DMVPN/NHRP, IKE/IPsec spans, priority guards, neutral states, and negatives"
}

Write-Host '[LIMITATION] Git/PCRE and .NET checks do not replace SecureCRT screen verification.'
