$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$profiles = @{
    Core = @{
        Path = Join-Path $repoRoot 'asa/ASA-SecureCRT-v1-Core.ini'
        Count = 46
    }
    Extended = @{
        Path = Join-Path $repoRoot 'asa/ASA-SecureCRT-v1-Extended.ini'
        Count = 64
    }
}

function Read-AsaProfile {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $profile = $profiles[$Name]
    $lines = Get-Content -LiteralPath $profile.Path

    if ($lines[0] -ne 'S:"Keyword List"=') {
        throw "$Name has an invalid V2 list header."
    }
    if ($lines -notcontains 'D:"Match Case"=00000001') {
        throw "$Name does not enable case-sensitive matching."
    }
    if ($lines -notcontains 'D:"Regex Line Mode"=00000001') {
        throw "$Name does not enable regex line mode."
    }

    $declaration = $lines | Where-Object { $_ -like 'Z:"Keyword List V2"=*' }
    if (@($declaration).Count -ne 1) {
        throw "$Name must contain one V2 count declaration."
    }
    $declaredCount = [Convert]::ToInt32(($declaration -split '=')[1], 16)

    $rules = @()
    foreach ($line in $lines) {
        if ($line -notmatch '^ "(.*)",([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})$') {
            continue
        }

        try {
            $compiled = [regex]::new(
                $matches[1],
                [System.Text.RegularExpressions.RegexOptions]::Multiline
            )
        }
        catch {
            throw "$Name contains an invalid regex: $($matches[1])"
        }

        $rules += [pscustomobject]@{
            Pattern = $matches[1]
            Color = $matches[2].ToLowerInvariant()
            Flag = $matches[3]
            Regex = $compiled
        }
    }

    if ($declaredCount -ne $profile.Count -or $rules.Count -ne $profile.Count) {
        throw "$Name rule count mismatch: declared=$declaredCount actual=$($rules.Count) expected=$($profile.Count)"
    }
    if (@($rules | Group-Object Pattern | Where-Object Count -gt 1).Count -ne 0) {
        throw "$Name contains duplicate patterns."
    }
    if ($rules[-1].Pattern -ne '.*|setasregextosetdefaultcolor' -or $rules[-1].Flag -ne '00000000') {
        throw "$Name does not end with the expected default-color fallback."
    }
    if (@($rules[0..($rules.Count - 2)] | Where-Object Flag -ne '00000001').Count -ne 0) {
        throw "$Name contains a non-regex rule before the fallback."
    }

    return ,$rules
}

$core = Read-AsaProfile -Name Core
$extended = Read-AsaProfile -Name Extended
Write-Output '[PASS] Core: header, line mode, count, shape, regex compilation, and fallback'
Write-Output '[PASS] Extended: header, line mode, count, shape, regex compilation, and fallback'

$extendedByPattern = @{}
foreach ($rule in $extended) {
    $extendedByPattern[$rule.Pattern] = $rule
}
foreach ($rule in $core) {
    if (-not $extendedByPattern.ContainsKey($rule.Pattern)) {
        throw "Extended is missing Core pattern: $($rule.Pattern)"
    }
    $extendedRule = $extendedByPattern[$rule.Pattern]
    if ($extendedRule.Color -ne $rule.Color -or $extendedRule.Flag -ne $rule.Flag) {
        throw "Extended changes the Core color or flag for: $($rule.Pattern)"
    }
}
Write-Output '[PASS] Core is a color/flag-consistent subset of Extended'

$integratedPath = Join-Path $repoRoot 'PNET-Cisco-Dark.ini'
$integratedLines = Get-Content -LiteralPath $integratedPath
$asaSectionHeader = ' "[*]ASA_FIREWALL_OPERATIONAL_STATES",00FFFFFF,00000001'
$criticalSectionHeader = ' "[*]CRITICAL_ERRORS_AND_DOWN_STATES",00FFFFFF,00000001'
$asaSectionStart = [array]::IndexOf([string[]]$integratedLines, $asaSectionHeader)
$criticalSectionStart = [array]::IndexOf([string[]]$integratedLines, $criticalSectionHeader)
if ($asaSectionStart -lt 0 -or $criticalSectionStart -lt 0 -or $asaSectionStart -ge $criticalSectionStart) {
    throw 'The integrated V2 list must place the ASA block before broad critical-state rules.'
}

$integratedAsaRules = @()
for ($index = $asaSectionStart + 1; $index -lt $criticalSectionStart; $index++) {
    $line = $integratedLines[$index]
    if ($line -notmatch '^ "(?<pattern>.*)",(?<color>[0-9A-Fa-f]{8}),(?<flag>[0-9A-Fa-f]{8})$') {
        throw "Unexpected integrated ASA row: $line"
    }
    $integratedAsaRules += [pscustomobject]@{
        Pattern = $matches['pattern']
        Color = $matches['color'].ToLowerInvariant()
        Flag = $matches['flag']
    }
}

$expectedIntegratedRules = @($extended | Where-Object Pattern -ne '.*|setasregextosetdefaultcolor')
if ($integratedAsaRules.Count -ne $expectedIntegratedRules.Count) {
    throw "Integrated ASA rule count mismatch: actual=$($integratedAsaRules.Count) expected=$($expectedIntegratedRules.Count)"
}
for ($index = 0; $index -lt $expectedIntegratedRules.Count; $index++) {
    $actual = $integratedAsaRules[$index]
    $expected = $expectedIntegratedRules[$index]
    if ($actual.Pattern -ne $expected.Pattern -or $actual.Color -ne $expected.Color -or $actual.Flag -ne $expected.Flag) {
        throw "Integrated ASA rule $index differs from Extended: actual=$($actual.Pattern) expected=$($expected.Pattern)"
    }
}
Write-Output '[PASS] Extended ASA rules are merged before broad integrated error/state rules'

$positiveCases = @(
    @{ Rules = $core; Text = 'Interface GigabitEthernet0/1 "OUTSIDE", is up, line protocol is up'; Color = '009cd48b'; Label = 'detail up' }
    @{ Rules = $core; Text = 'GigabitEthernet0/0         unassigned      YES unset  administratively down up'; Color = '00a6a09a'; Label = 'brief admin down' }
    @{ Rules = $core; Text = 'GigabitEthernet0/1         2.2.2.1         YES manual up                    up'; Color = '009cd48b'; Label = 'brief up' }
    @{ Rules = $core; Text = "`tThis host: Primary - Active"; Color = '00ffc878'; Label = 'one-line active' }
    @{ Rules = $core; Text = "`tOther host: Secondary - Standby Ready"; Color = '00e7a7c4'; Label = 'one-line standby' }
    @{ Rules = $core; Text = 'This host  -   Primary'; Color = '00ffc878'; Label = 'split role' }
    @{ Rules = $core; Text = '               Active         None'; Color = '009cd48b'; Label = 'split active' }
    @{ Rules = $core; Text = '               Active         Ifc Failure             22:49:06 UTC Sep 13 2026'; Color = '009cd48b'; Label = 'split active with historical interface failure' }
    @{ Rules = $core; Text = '               Standby Ready  Comm Failure             13:57:46 UTC Sep 13 2026'; Color = '00e7a7c4'; Label = 'split standby history' }
    @{ Rules = $core; Text = '               Standby Ready  Ifc Failure              21:27:48 UTC Sep 13 2026'; Color = '00e7a7c4'; Label = 'split standby with historical interface failure' }
    @{ Rules = $core; Text = 'Interface inside (192.168.1.2): Failed'; Color = '000000ff'; Label = 'failover interface failed' }
    @{ Rules = $core; Text = 'Interface inside (192.168.1.2): Normal (Waiting)'; Color = '0066aaff'; Label = 'failover interface waiting' }
    @{ Rules = $core; Text = 'Sync Done - STANDBY'; Color = '009cd48b'; Label = 'standby config sync done' }
    @{ Rules = $core; Text = 'Sync Skipped'; Color = '009cd48b'; Label = 'matching config sync skipped' }
    @{ Rules = $core; Text = 'ASAv Platform License State: Unlicensed'; Color = '000000ff'; Label = 'ASAv unlicensed state' }
    @{ Rules = $core; Text = 'Warning: ASAv platform license state is Unlicensed.'; Color = '000000ff'; Label = 'ASAv unlicensed warning' }
    @{ Rules = $core; Text = 'No active entitlement: no feature tier and no throughput level configured'; Color = '000000ff'; Label = 'missing active entitlement with detail' }
    @{ Rules = $core; Text = 'vCPU Status: Noncompliant: Over-provisioned'; Color = '000000ff'; Label = 'ASAv noncompliant resource' }
    @{ Rules = $core; Text = 'ASAv platform license state is Compliant'; Color = '009cd48b'; Label = 'ASAv compliant state' }
    @{ Rules = $core; Text = 'Reachability is UP'; Color = '009cd48b'; Label = 'SLA track up' }
    @{ Rules = $core; Text = 'Reachability is DOWN'; Color = '000000ff'; Label = 'SLA track down' }
    @{ Rules = $core; Text = 'Latest operation return code: OK'; Color = '009cd48b'; Label = 'SLA return code OK' }
    @{ Rules = $core; Text = 'Server status: ACTIVE (admin initiated). Last Transaction at 11:40:09 UTC'; Color = '009cd48b'; Label = 'AAA server active' }
    @{ Rules = $core; Text = 'Server status: FAILED.'; Color = '000000ff'; Label = 'AAA server failed' }
    @{ Rules = $core; Text = 'Reload scheduled for 00:00:00 PDT Sat April 20 (in 12 hours and 12 minutes)'; Color = '0066aaff'; Label = 'scheduled reload' }
    @{ Rules = $core; Text = 'Right Slot (PS1): Failure Detected'; Color = '000000ff'; Label = 'environment power failure' }
    @{ Rules = $extended; Text = "`t390 L2 decode drops"; Color = '0066d8ff'; Label = 'nonzero L2 drops' }
    @{ Rules = $extended; Text = 'Auto NAT Policies (Section 2)'; Color = '00ffc878'; Label = 'NAT section' }
    @{ Rules = $extended; Text = '    translate_hits = 14, untranslate_hits = 0'; Color = '00ffc878'; Label = 'NAT counters' }
    @{ Rules = $extended; Text = 'TCP PAT from INSIDE:192.168.1.100/50062 to OUTSIDE:2.2.2.1/50062 flags ri idle 0:00:14 timeout 0:00:30'; Color = '00ffc878'; Label = 'xlate protocol' }
    @{ Rules = $extended; Text = 'CPU utilization for 5 seconds = 7%; 1 minute: 2%; 5 minutes: 1%'; Color = '00ffc878'; Label = 'CPU' }
    @{ Rules = $extended; Text = 'Free memory:        1088409600 bytes (51%)'; Color = '00ffc878'; Label = 'free memory' }
    @{ Rules = $extended; Text = 'Used memory:        1059074048 bytes (49%)'; Color = '00ffc878'; Label = 'used memory' }
    @{ Rules = $extended; Text = 'Total memory:       2147483648 bytes (100%)'; Color = '00ffc878'; Label = 'total memory information' }
    @{ Rules = $extended; Text = 'Cisco Adaptive Security Appliance Software Version 9.8(1)'; Color = '00ffc878'; Label = 'version' }
    @{ Rules = $extended; Text = 'PID: ASAv              , VID: V01     , SN: 9A3H2MFWGU5'; Color = '00ffc878'; Label = 'PID' }
    @{ Rules = $extended; Text = 'interface GigabitEthernet0/1'; Color = '00ffc878'; Label = 'config interface' }
    @{ Rules = $extended; Text = 'object network PC1_network'; Color = '00ffc878'; Label = 'config object' }
    @{ Rules = $extended; Text = 'Inspect: esmtp _default_esmtp_map, packet 96716502, lock fail 7, drop 25, reset-drop 0'; Color = '0066d8ff'; Label = 'nonzero inspection drop' }
    @{ Rules = $extended; Text = 'Interface outside: aggregate drop 9, aggregate transmit 5207048'; Color = '0066d8ff'; Label = 'nonzero priority drop' }
    @{ Rules = $extended; Text = 'Conns [rate]              270          535      42200       1704 Summary'; Color = '0066d8ff'; Label = 'resource denied counter' }
    @{ Rules = $extended; Text = 'NAT reverse path failed (nat-rpf-failed) 22266'; Color = '0066d8ff'; Label = 'ASP drop reason' }
    @{ Rules = $extended; Text = 'Neighbor priority is 1, State is FULL, 6 state changes'; Color = '009cd48b'; Label = 'OSPF full neighbor' }
    @{ Rules = $extended; Text = 'Neighbor priority is 1, State is EXSTART, 6 state changes'; Color = '0066aaff'; Label = 'OSPF incomplete neighbor' }
    @{ Rules = $extended; Text = 'Status: Pending terminal enrollment'; Color = '0066aaff'; Label = 'pending certificate enrollment' }
)

$negativeCases = @(
    @{ Rules = $core; Text = 'State          Last Failure Reason      Date/Time'; Label = 'failure history header' }
    @{ Rules = $core; Text = 'Last Failover at: 13:56:27 UTC Sep 13 2026'; Label = 'last failover history' }
    @{ Rules = $core; Text = 'There are no IKEv1 SAs'; Label = 'no IKEv1 SA' }
    @{ Rules = $core; Text = 'Gateway of last resort is not set'; Label = 'missing default route' }
    @{ Rules = $core; Text = 'Interface inside (192.168.1.1): Normal (Monitored)'; Label = 'normal monitored failover interface' }
    @{ Rules = $core; Text = 'Standby Ready  Comm Failure             12:53:10 UTC Apr 26 2017'; Label = 'historical failover reason without state row' }
    @{ Rules = $core; Text = 'Last Failure Reason: Comm Failure'; Label = 'historical failover reason label' }
    @{ Rules = $extended; Text = "`t0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored, 0 abort"; Label = 'zero interface errors' }
    @{ Rules = $extended; Text = '0 in use, 2 most used'; Label = 'empty xlate summary' }
    @{ Rules = $extended; Text = 'Syslog logging: disabled'; Label = 'logging disabled' }
    @{ Rules = $extended; Text = "`tTCP conn`t20`t0`t0`t0"; Label = 'failover TCP statistics' }
    @{ Rules = $extended; Text = "`tUDP conn`t0`t0`t0`t0"; Label = 'failover UDP statistics' }
    @{ Rules = $extended; Text = 'Inspect: ftp strict inbound_ftp, packet 0, drop 0, reset-drop 0'; Label = 'zero inspection drop' }
    @{ Rules = $extended; Text = 'Conns                     584          763     100000(S)       0 Summary'; Label = 'zero resource denied counter' }
    @{ Rules = $extended; Text = 'NAT failed (nat-failed) 0'; Label = 'zero ASP drop reason' }
    @{ Rules = $extended; Text = 'Neighbor priority is 1, State is WAITING, 0 state changes'; Label = 'OSPF transient waiting state' }
    @{ Rules = $extended; Text = 'Status: Available'; Label = 'available certificate' }
)

foreach ($case in $positiveCases) {
    $matchingRules = @($case.Rules | Where-Object {
        $_.Flag -eq '00000001' -and $_.Regex.IsMatch($case.Text)
    })
    if (@($matchingRules | Where-Object Color -eq $case.Color).Count -eq 0) {
        throw "Actual-output positive mismatch: $($case.Label)"
    }
    $unexpectedColors = @($matchingRules | Where-Object Color -ne $case.Color)
    if ($unexpectedColors.Count -ne 0) {
        throw "Actual-output color conflict for $($case.Label): $($unexpectedColors.Color -join ', ')"
    }
}

foreach ($case in $negativeCases) {
    $matchingRules = @($case.Rules | Where-Object {
        $_.Flag -eq '00000001' -and $_.Regex.IsMatch($case.Text)
    })
    if ($matchingRules.Count -ne 0) {
        throw "Actual-output false positive for $($case.Label): $($matchingRules.Pattern -join '; ')"
    }
}

$actualCaseCount = $positiveCases.Count + $negativeCases.Count
Write-Output "[PASS] ASA output regression cases: $actualCaseCount"
