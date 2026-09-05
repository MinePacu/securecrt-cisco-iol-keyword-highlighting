# Git/PCRE exercises the INI's literal patterns (not a .NET rewrite).
# This verifies matching semantics; SecureCRT rendering/precedence needs a UI check.
param([string]$GitPath = 'git')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $PSScriptRoot 'fixtures/NatTranslations.txt'
$samples = [IO.File]::ReadAllLines($fixture)

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-PatternMatches([string]$Pattern) {
    $output = @(& $GitPath -C $root -c core.quotepath=false grep --no-index --color=never -h -n --column -o -P -e $Pattern -- tests/fixtures/NatTranslations.txt)
    Assert-That ($LASTEXITCODE -in @(0, 1)) "Git/PCRE failed to evaluate: $Pattern"
    # This bundled Git reports the resumed search offset for later -o matches
    # on a line, not necessarily the actual match offset. Use .NET for spans;
    # current integrated patterns are shared syntax without DEFINE or keep-out.
    for ($lineIndex=0; $lineIndex -lt $samples.Count; $lineIndex++) {
        foreach ($hit in [regex]::Matches($samples[$lineIndex],$Pattern)) {
            [pscustomobject]@{ Line = $lineIndex+1; Column = $hit.Index+1; Text = $hit.Value }
        }
    }
}

$columnColors = @('00B469FF', '0000D7FF', '00FFFF00', '00FACE87', '00EE82EE')
$expected = @{}
# Original positives and the user's screenshot; other lines are negatives.
foreach ($n in @((0..9) + (23..26))) {
    $isHeader = $n -in @(0, 8, 23)
    $tokens = if ($isHeader) {
        [regex]::Matches($samples[$n], 'Pro|Inside global|Inside local|Outside local|Outside global')
    } else {
        [regex]::Matches($samples[$n], '\S+')
    }
    Assert-That ($tokens.Count -eq 5) "Fixture $n must have five columns"
    for ($c = 0; $c -lt 5; $c++) {
        $token = $tokens[$c]
        $color = if ($token.Value -eq '---') { '00C0C0C0' }
            elseif ($isHeader -and $c -eq 0) { '00FFFFFF' }
            else { $columnColors[$c] }
        $key = '{0}:{1}:{2}' -f ($n + 1), ($token.Index + 1), $token.Value
        $expected[$key] = $color
    }
}

foreach ($version in @('V2', 'V3')) {
    $name = if ($version -eq 'V2') { 'PNET-Cisco-Dark.ini' } else { 'PNET-Cisco-Dark-V3.ini' }
    $rows = @()
    $section = ''
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $root $name))) {
        if ($line -match '^ "\[\*\]([^"]+)"') { $section = $Matches[1]; continue }
        if ($line -match '^ "([^"]+)",([0-9A-F]{8}),') {
            $rows += [pscustomobject]@{ Pattern = $Matches[1]; Color = $Matches[2]; Section = $section }
        }
    }
    $natRows = @($rows | Where-Object Section -eq 'SHOW_IP_NAT_TRANSLATIONS')
    Assert-That ($natRows.Count -eq 11) "$version must have 11 NAT behavior rules"
    Assert-That ($rows[0].Section -eq 'SHOW_ACCESS_LISTS') "$version ACL row protection must precede NAT"
    Assert-That ($natRows[-1].Pattern -ceq '---') "$version placeholders must follow address rules"
    $actual = @{}
    foreach ($rule in $natRows) {
        Assert-That (-not $rule.Pattern.Contains('\K')) "$version must not consume a prefix then reset its match"
        foreach ($hit in @(Get-PatternMatches $rule.Pattern)) {
            # Suffix rules are not NAT detectors. Negative fixtures are checked
            # below for priority protection or explicitly recorded residual risk.
            if ($hit.Line -notin @((1..10) + (24..27))) { continue }
            $key = '{0}:{1}:{2}' -f $hit.Line, $hit.Column, $hit.Text
            Assert-That (-not $actual.ContainsKey($key)) "$version overlapping NAT rules: $key"
            $actual[$key] = $rule.Color
            # Require evaluation to begin AT the highlighted token. The previous
            # ^prefix\Ktoken implementation fails this check for later columns.
            # This is a candidate-start regression, not a native renderer emulator.
            $atToken = '(?<=^.{' + ($hit.Column - 1) + '})' + $rule.Pattern
            $candidateHits = @(Get-PatternMatches $atToken | Where-Object {
                $_.Line -eq $hit.Line -and $_.Column -eq $hit.Column -and $_.Text -ceq $hit.Text
            })
            Assert-That ($candidateHits.Count -eq 1) "$version cannot begin matching at token $key"
        }
    }
    Assert-That ($actual.Count -eq $expected.Count) "$version expected $($expected.Count) colored spans, got $($actual.Count)"
    foreach ($key in $expected.Keys) {
        Assert-That ($actual[$key] -ceq $expected[$key]) "$version incorrect color/span at $key"
    }
    $bgpValues = @($rows | Where-Object {
        $_.Section -eq 'BGP_SHOW_IP' -and $_.Pattern.StartsWith('\x20+')
    })
    Assert-That ($bgpValues.Count -eq 1) 'BGP route-value rule must be uniquely identifiable'
    $bgpHits = @(Get-PatternMatches $bgpValues[0].Pattern)
    Assert-That (($bgpHits.Line -join ',') -eq '17,18,19') "$version BGP values must match BGP fixtures only, not address-only NAT"
    $permit = @($rows | Where-Object { $_.Section -eq 'SHOW_ACCESS_LISTS' -and $_.Color -eq '0032CD32' })
    $aclHits = @(Get-PatternMatches $permit[0].Pattern)
    Assert-That (($aclHits.Line -join ',') -eq '20') "$version ACL fixture must still match"
    $guards = @($rows | Where-Object Section -eq 'NAT_CONTEXT_GUARDS')
    foreach ($guard in $guards) {
        $bad = @(Get-PatternMatches $guard.Pattern | Where-Object { $_.Line -in @((1..10)+(24..27)) })
        Assert-That ($bad.Count -eq 0) "$version guard must not mask valid NAT fixtures"
    }
    $cases = @(
        @{Text='10 permit ip host 192.0.2.1 host 198.51.100.1';Token='198.51.100.1';Color='0032CD32'},
        @{Text='20 deny ip host 192.0.2.1 host 198.51.100.1';Token='198.51.100.1';Color='000000FF'},
        @{Text='Gateway of last resort is 192.0.2.1 to network 0.0.0.0';Token='0.0.0.0';Color='0000D7FF'},
        @{Text='Connected to 198.51.100.1:443';Token='198.51.100.1';Color='0000D7FF'},
        @{Text='via 198.51.100.1';Token='198.51.100.1';Color='0000D7FF'},
        @{Text='Cluster list: 192.0.2.1, 198.51.100.1';Token='198.51.100.1';Color='0000D7FF'}
    )
    # Ordered full-subject match model: verifies priority coverage, not native
    # SecureCRT segmentation or rendering. Must still check integrated UI.
    $early = @($rows | Where-Object { $_.Section -in @('SHOW_ACCESS_LISTS','NAT_CONTEXT_GUARDS','SHOW_IP_NAT_TRANSLATIONS') })
    foreach ($case in $cases) {
        $start = $case.Text.LastIndexOf($case.Token)
        $winner = $null
        foreach ($rule in $early) {
            foreach ($m in [regex]::Matches($case.Text,$rule.Pattern)) {
                if ($m.Index -le $start -and $m.Index+$m.Length -ge $start+$case.Token.Length) { $winner=$rule; break }
            }
            if ($null -ne $winner) { break }
        }
        Assert-That ($null -ne $winner -and $winner.Color -ceq $case.Color -and $winner.Section -ne 'SHOW_IP_NAT_TRANSLATIONS') "$version missing priority guard: $($case.Text)"
    }
    $lastNat = $natRows | Where-Object Color -eq '00EE82EE' | Select-Object -Last 1
    Assert-That ([regex]::IsMatch('Peer 198.51.100.1', $lastNat.Pattern)) 'Residual non-NAT suffix ambiguity must remain documented'
    Write-Host "[PASS] ${version}: $($expected.Count) NAT spans and candidate starts; guards disjoint from positives; six priority cases; BGP/ACL regression"
    Write-Host '[LIMITATION] Native screenshot coverage is documented in docs/NAT-Highlighting-Status.md; unguarded text and incomplete NAT rows can still receive incorrect role colors.'
}
