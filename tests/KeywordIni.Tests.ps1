$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Actual -is [string] -and $Expected -is [string]) {
        $equal = [string]::Equals($Actual, $Expected, [System.StringComparison]::Ordinal)
    }
    else {
        $equal = $Actual -eq $Expected
    }

    Assert-True -Condition ([bool]$equal) -Message "$Message (actual: $Actual; expected: $Expected)"
}

$iniPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'PNET-Cisco-Dark.ini'))
$iniText = [System.IO.File]::ReadAllText($iniPath)
$lines = $iniText -split '\r?\n'
$sectionStart = -1
$sectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]OSPF_PROCESS_AREA_AND_IDS",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $sectionStart = $index
        break
    }
}

Assert-True -Condition ($sectionStart -ge 0) -Message 'OSPF_PROCESS_AREA_AND_IDS section must exist'

for ($index = $sectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $sectionEnd = $index
        break
    }
}

$sectionLines = $lines[$sectionStart..($sectionEnd - 1)]
$sectionText = [string]::Join([System.Environment]::NewLine, $sectionLines)
$expectedPatterns = @(
    '\bIt is an autonomous system boundary router\b',
    '\bIt is an area border and autonomous system boundary router\b'
)

foreach ($expectedPattern in $expectedPatterns) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($expectedPattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",00FFFF00,00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $sectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "ASBR rule has exact pattern and yellow color: $expectedPattern"

    $sample = $expectedPattern -replace '\\b', ''
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $expectedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ASBR rule matches Cisco IOS phrase: $sample"
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            "prefix$sample",
            $expectedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ASBR rule respects the leading word boundary: $expectedPattern"
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            "${sample}suffix",
            $expectedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ASBR rule respects the trailing word boundary: $expectedPattern"
}

Write-Host '[PASS] OSPF ASBR phrase rules are present with exact yellow highlighting'

$costSectionStart = -1
$costSectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]OSPF_COST_METRIC_REFERENCE_BW",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $costSectionStart = $index
        break
    }
}

Assert-True -Condition ($costSectionStart -ge 0) -Message 'OSPF_COST_METRIC_REFERENCE_BW section must exist'

for ($index = $costSectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $costSectionEnd = $index
        break
    }
}

$costSectionLines = $lines[$costSectionStart..($costSectionEnd - 1)]
$costSectionText = [string]::Join([System.Environment]::NewLine, $costSectionLines)
$costPattern = '\b[Cc]ost\s*:\s*[0-9]+\b'
$costRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($costPattern) + '",0000D7FF,00000001\s*$'
$costRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costSectionText,
    $costRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $costRuleMatches.Count -Expected 1 -Message 'Cost: numeric rule has exact gold color'

foreach ($sample in @('Cost: 1', '  Cost:   65535', 'Cost : 10', 'cost: 10')) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $costPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Cost: numeric rule matches Cisco IOS output: $sample"
}

foreach ($sample in @('Cost 1', 'Costs: 1', 'preCost: 1', 'Cost: 1ms')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $costPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Cost: numeric rule rejects non-matching output: $sample"
}

Write-Host '[PASS] OSPF Cost: numeric rule matches actual output with exact gold highlighting'
