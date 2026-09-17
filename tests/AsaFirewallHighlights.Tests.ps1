# The preserved upstream ASA package supplies the independently verified
# Extended rule set and its 62 positive/negative cases. This test additionally
# proves that both root production lists contain those 63 regex rules verbatim.
param([string]$GitPath = 'git')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$packageRoot = if (Test-Path -LiteralPath (Join-Path $root 'asa/ASA-SecureCRT-v1-Extended.ini')) {
    $root
}
else {
    Join-Path $root 'dist/upstream-main'
}
$upstreamTest = Join-Path $packageRoot 'tests/AsaKeywordLists.Tests.ps1'
$extendedPath = Join-Path $packageRoot 'asa/ASA-SecureCRT-v1-Extended.ini'
$asaReadmePath = Join-Path $packageRoot 'asa/ASA-SecureCRT-v1-README.md'

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-AsaRows([string]$Path, [string]$Version) {
    $lines = [IO.File]::ReadAllLines($Path)
    $headerSuffix = if ($Version -eq 'V3') { ',00000001' } else { '' }
    $header = ' "[*]ASA_FIREWALL_OPERATIONAL_STATES",00FFFFFF,00000001' + $headerSuffix
    $start = [array]::IndexOf([string[]]$lines, $header)
    Assert-That ($start -ge 0) "$Version ASA section header is missing"

    $rows = @()
    for ($index = $start + 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^ "\[\*\]') { break }
        $pattern = if ($Version -eq 'V3') {
            '^ "(?<Pattern>.*)",(?<Color>[0-9A-Fa-f]{8}),(?<Flag>[0-9A-Fa-f]{8}),00000001$'
        }
        else {
            '^ "(?<Pattern>.*)",(?<Color>[0-9A-Fa-f]{8}),(?<Flag>[0-9A-Fa-f]{8})$'
        }
        Assert-That ($lines[$index] -match $pattern) "$Version malformed ASA row: $($lines[$index])"
        $rows += [pscustomobject]@{
            Pattern = $Matches.Pattern
            Color = $Matches.Color.ToLowerInvariant()
            Flag = $Matches.Flag
        }
    }
    return $rows
}

function Get-ExtendedRows {
    $rows = @()
    foreach ($line in [IO.File]::ReadAllLines($extendedPath)) {
        if ($line -match '^ "(?<Pattern>.*)",(?<Color>[0-9A-Fa-f]{8}),(?<Flag>[0-9A-Fa-f]{8})$' -and
            $Matches.Pattern -ne '.*|setasregextosetdefaultcolor') {
            $rows += [pscustomobject]@{
                Pattern = $Matches.Pattern
                Color = $Matches.Color.ToLowerInvariant()
                Flag = $Matches.Flag
            }
        }
    }
    return $rows
}

& pwsh -NoProfile -File $upstreamTest
Assert-That ($LASTEXITCODE -eq 0) 'Preserved ASA package regression failed'

$expected = @(Get-ExtendedRows)
Assert-That ($expected.Count -eq 63) "Expected 63 ASA Extended regex rules, got $($expected.Count)"

foreach ($version in @('V2', 'V3')) {
    $path = Join-Path $root $(if ($version -eq 'V3') { 'PNET-Cisco-Dark-V3.ini' } else { 'PNET-Cisco-Dark.ini' })
    $actual = @(Get-AsaRows -Path $path -Version $version)
    Assert-That ($actual.Count -eq $expected.Count) "$version integrated ASA rule count mismatch"

    for ($index = 0; $index -lt $expected.Count; $index++) {
        $want = $expected[$index]
        $got = $actual[$index]
        Assert-That ($got.Pattern -ceq $want.Pattern) "$version ASA pattern differs at index $index"
        Assert-That ($got.Color -ceq $want.Color) "$version ASA color differs at index $index"
        Assert-That ($got.Flag -ceq $want.Flag) "$version ASA flag differs at index $index"
    }

    foreach ($rule in $actual) {
        $null = [regex]::new($rule.Pattern)
        $null = & $GitPath -c core.quotepath=false grep --no-index --color=never -h -P -e $rule.Pattern -- $asaReadmePath
        Assert-That ($LASTEXITCODE -in @(0, 1)) "$version Git/PCRE failed to evaluate ASA pattern: $($rule.Pattern)"
    }

    $lines = [IO.File]::ReadAllLines($path)
    $sectionNames = @($lines | ForEach-Object { if ($_ -match '^ "\[\*\](?<Name>[^"]+)"') { $Matches.Name } })
    $bgp = [array]::IndexOf($sectionNames, 'BGP_SHOW_IP')
    $asa = [array]::IndexOf($sectionNames, 'ASA_FIREWALL_OPERATIONAL_STATES')
    $tunnel = [array]::IndexOf($sectionNames, 'TUNNEL_GRE_INTERFACE')
    $critical = [array]::IndexOf($sectionNames, 'CRITICAL_ERRORS_AND_DOWN_STATES')
    Assert-That ($bgp -lt $asa -and $asa -lt $tunnel -and $tunnel -lt $critical) "$version ASA priority order is incorrect"

    Write-Host "[PASS] $version contains all 63 Extended ASA rules before tunnel and broad state rules"
}

Write-Host '[LIMITATION] Offline regex checks do not replace SecureCRT native rendering verification.'
