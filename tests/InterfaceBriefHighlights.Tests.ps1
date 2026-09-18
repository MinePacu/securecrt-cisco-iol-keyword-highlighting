param([string]$GitPath = 'git')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixtureRelative = 'tests/fixtures/InterfaceBriefOutputs.txt'
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
            $rules += [pscustomobject]@{
                Pattern = $Matches.Pattern
                Color = $Matches.Color.ToUpperInvariant()
                Section = $section
                Regex = [regex]::new($Matches.Pattern)
            }
        }
    }
    return $rules
}

function Get-FirstCoveringRule($Rules, [string]$Text, [string]$Token, [int]$Occurrence = 1) {
    $start = -1
    $searchFrom = 0
    for ($index = 0; $index -lt $Occurrence; $index++) {
        $start = $Text.IndexOf($Token, $searchFrom, [StringComparison]::Ordinal)
        Assert-That ($start -ge 0) "Token '$Token' occurrence $Occurrence is missing from: $Text"
        $searchFrom = $start + $Token.Length
    }
    foreach ($rule in $Rules) {
        foreach ($match in $rule.Regex.Matches($Text)) {
            if ($match.Index -le $start -and $match.Index + $match.Length -ge $start + $Token.Length) {
                return $rule
            }
        }
    }
    return $null
}

$cases = @(
    @{ Line = 1; Token = 'Ethernet0/0'; Color = '00FFFF00' },
    @{ Line = 1; Token = '10.1.12.2'; Color = '0000D7FF' },
    @{ Line = 1; Token = 'YES'; Color = '00FFFFFF' },
    @{ Line = 1; Token = 'manual'; Color = '00FFFFFF' },
    @{ Line = 1; Token = 'up'; Occurrence = 1; Color = '0032CD32' },
    @{ Line = 1; Token = 'up'; Occurrence = 2; Color = '0032CD32' },
    @{ Line = 3; Token = 'unassigned'; Color = '00FFFFFF' },
    @{ Line = 3; Token = 'NVRAM'; Color = '00FFFFFF' },
    @{ Line = 4; Token = 'administratively'; Color = '000000FF' },
    @{ Line = 4; Token = 'down'; Occurrence = 1; Color = '000000FF' },
    @{ Line = 4; Token = 'down'; Occurrence = 2; Color = '000000FF' },
    @{ Line = 5; Token = 'GigabitEthernet0/1'; Color = '00FFFF00' }
)

foreach ($version in @('V2', 'V3')) {
    $rules = @(Get-Rules $version)
    $guardRules = @($rules | Where-Object Section -eq 'IOS_SHOW_IP_INTERFACE_BRIEF')
    Assert-That ($guardRules.Count -eq 6) "$version interface-brief guard rule count changed: $($guardRules.Count)"
    foreach ($rule in $guardRules) {
        $null = & $GitPath -C $root -c core.quotepath=false grep --no-index --color=never -h -P -e $rule.Pattern -- $fixtureRelative
        Assert-That ($LASTEXITCODE -in @(0, 1)) "$version Git/PCRE failed to evaluate: $($rule.Pattern)"
    }

    foreach ($case in $cases) {
        $text = $samples[$case.Line]
        $occurrence = if ($case.ContainsKey('Occurrence')) { $case.Occurrence } else { 1 }
        $winner = Get-FirstCoveringRule $rules $text $case.Token $occurrence
        Assert-That ($null -ne $winner) "$version has no rule for '$($case.Token)' in '$text'"
        Assert-That ($winner.Section -eq 'IOS_SHOW_IP_INTERFACE_BRIEF') "$version '$($case.Token)' is captured first by $($winner.Section)"
        Assert-That ($winner.Color -eq $case.Color) "$version '$($case.Token)' color is $($winner.Color), expected $($case.Color)"
    }

    foreach ($negative in @(
        @{ Text = 'Ethernet0/0 10.1.12.2 YES manual up'; Token = 'Ethernet0/0' },
        @{ Text = 'The Ethernet0/0 interface is up'; Token = 'Ethernet0/0' }
    )) {
        $start = $negative.Text.IndexOf($negative.Token, [StringComparison]::Ordinal)
        foreach ($rule in $guardRules) {
            foreach ($match in $rule.Regex.Matches($negative.Text)) {
                $coversToken = $match.Index -le $start -and $match.Index + $match.Length -ge $start + $negative.Token.Length
                Assert-That (-not $coversToken) "$version interface-brief guard false-positive for '$($negative.Token)': $($negative.Text)"
            }
        }
    }
}

Write-Output '[PASS] V2/V3 show ip interface brief tokens retain pre-ASA colors ahead of whole-row ASA rules; PCRE evaluation passed'
Write-Output '[LIMITATION] IOS and ASA brief rows share the same line format; the integrated list therefore uses the tokenized style for both.'
