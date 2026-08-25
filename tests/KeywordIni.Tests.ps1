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

function Get-IniSectionText {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    $sectionStart = -1
    $sectionEnd = $Lines.Count

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch(
                $Lines[$index],
                ('^\s*"\[\*\]{0}",' -f [System.Text.RegularExpressions.Regex]::Escape($SectionName)),
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) {
            $sectionStart = $index
            break
        }
    }

    Assert-True -Condition ($sectionStart -ge 0) -Message "$SectionName section must exist"

    for ($index = $sectionStart + 1; $index -lt $Lines.Count; $index++) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch(
                $Lines[$index],
                '^\s*"\[\*\]',
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) {
            $sectionEnd = $index
            break
        }
    }

    $sectionLines = $Lines[$sectionStart..($sectionEnd - 1)]
    return [string]::Join([System.Environment]::NewLine, $sectionLines)
}

$iniPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'PNET-Cisco-Dark.ini'))
$iniText = [System.IO.File]::ReadAllText($iniPath)
$lines = $iniText -split '\r?\n'

$keywordCountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $iniText,
    '(?m)^Z:"Keyword List V2"=([0-9A-Fa-f]{8})\s*$'
)
Assert-True -Condition $keywordCountMatch.Success -Message 'keyword list must declare its V2 entry count'
$declaredKeywordCount = [Convert]::ToInt32($keywordCountMatch.Groups[1].Value, 16)
$keywordEntryCount = @(
    $lines | Where-Object {
        [System.Text.RegularExpressions.Regex]::IsMatch(
            $_,
            '^\s+"',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
    }
).Count
Assert-Equal -Actual $declaredKeywordCount -Expected $keywordEntryCount -Message 'Keyword List V2 entry count must include every keyword rule'
Write-Host '[PASS] SecureCRT keyword list metadata includes every keyword rule'

$regexLineModeMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $iniText,
    '(?m)^\s*D:"Regex Line Mode"=([01]{8})\s*$',
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $regexLineModeMatches.Count -Expected 1 -Message 'keyword list must explicitly configure Regex Line Mode once'
Assert-Equal -Actual $regexLineModeMatches[0].Groups[1].Value -Expected '00000001' -Message 'Regex Line Mode must be enabled for line-anchored prompt rules'
Write-Host '[PASS] SecureCRT regex line mode is enabled for line-anchored prompt rules'
$sectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_PROCESS_AREA_AND_IDS'
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

$areaRules = @(
    @{
        Pattern = '\bArea(?:\x20ID)?\x20+(?:[0-9]+|(?:[0-9]{1,3}\.){3}[0-9]{1,3})\b'
        Color = '00FACE87'
        Matches = @(
            'Area 1',
            '    Area 1',
            'Area ID 1',
            'Area 0.0.0.0',
            '  Area ID 10.0.0.1'
        )
        Rejects = @('Area 1x', 'Area BACKBONE(0)')
    },
    @{
        Pattern = '\bArea(?:\x20ID)?\x20+BACKBONE\(0\)'
        Color = '00FACE87'
        Matches = @('Area BACKBONE(0)', '    Area BACKBONE(0)', 'Area ID BACKBONE(0)')
        Rejects = @('Area BACKBONE(1)', 'SubArea BACKBONE(0)')
    }
)

foreach ($areaRule in $areaRules) {
    Assert-True -Condition (-not $areaRule.Pattern.Contains('\s')) -Message "Area rule must use SecureCRT literal-space syntax: $($areaRule.Pattern)"
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($areaRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $areaRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $sectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Area rule has exact pattern and color: $($areaRule.Pattern)"

    foreach ($sample in $areaRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $areaRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Area rule matches Cisco IOS output: $sample"
    }

    foreach ($sample in $areaRule.Rejects) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $areaRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Area rule rejects non-matching output: $sample"
    }
}

$areaTranscript = @(
    '      Area BACKBONE(0)',
    '      Area 1'
) -join [Environment]::NewLine
$areaTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$backboneTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $areaTranscript,
    $areaRules[1].Pattern,
    $areaTranscriptOptions
)
$numericTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $areaTranscript,
    $areaRules[0].Pattern,
    $areaTranscriptOptions
)
Assert-Equal -Actual $backboneTranscriptMatches.Count -Expected 1 -Message 'indented Area BACKBONE(0) transcript line must match'
Assert-Equal -Actual $numericTranscriptMatches.Count -Expected 1 -Message 'indented Area 1 transcript line must match'

Write-Host '[PASS] Cisco Area rules match indented BACKBONE(0), numeric, and IP output'

$neighborSectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_NEIGHBOR_STATES'
$fullPattern = '\bFULL\b'
$fullRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($fullPattern) + '",0032CD32,00000001\s*$'
$fullRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $neighborSectionText,
    $fullRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $fullRuleMatches.Count -Expected 1 -Message 'standalone OSPF FULL rule has exact green color'
Assert-True -Condition (-not $fullPattern.Contains('\s')) -Message 'standalone OSPF FULL rule must use SecureCRT-compatible syntax'

$neighborLogTranscript = @(
    'Aug 25 11:51:06: %OSPF-5-ADJCHG: Process 12, Nbr 10.0.0.2 on GigabitEthernet0/0/2 from LOADING to FULL, Loading Done',
    '*Mar  8 17:47:03.345: OSPFv3-1-IPv6 ADJ Gi0/0: Synchronized with 10.1.1.1, state FULL'
) -join [Environment]::NewLine
$neighborTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$neighborLogMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $neighborLogTranscript,
    $fullPattern,
    $neighborTranscriptOptions
)
Assert-Equal -Actual $neighborLogMatches.Count -Expected 2 -Message 'standalone FULL rule matches Cisco OSPF adjacency log variants'
Assert-True -Condition (($neighborLogMatches | ForEach-Object { $_.Value }) -contains 'FULL') -Message 'standalone FULL rule must match the Cisco neighbor state token'

foreach ($falseFullSample in @('FULLY', 'FULLNESS', 'preFULL', 'FULL_suffix')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $falseFullSample,
            $fullPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "standalone FULL rule rejects false-positive token: $falseFullSample"
}

Write-Host '[PASS] OSPF neighbor FULL state logs receive standalone green highlighting without false positives'

$costSectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_COST_METRIC_REFERENCE_BW'
$costFullPattern = '\b[Cc]ost\x20*:\x20*[0-9]+\b'
$costPattern = '\b[Cc]ost\b'
$costFullRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($costFullPattern) + '",0000D7FF,00000001\s*$'
$costFullRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costSectionText,
    $costFullRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $costFullRuleMatches.Count -Expected 1 -Message 'Cost full phrase rule has exact gold color'
Assert-True -Condition (-not $costFullPattern.Contains('\s')) -Message 'Cost full phrase rule must use SecureCRT literal-space syntax'
$costRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($costPattern) + '",0000D7FF,00000001\s*$'
$costRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costSectionText,
    $costRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $costRuleMatches.Count -Expected 1 -Message 'Cost token rule has exact gold color'

$costTranscript = @(
    '      Cost: 10',
    '      Cost : 10',
    '      cost: 20',
    '      cost 20'
) -join [Environment]::NewLine
$transcriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$costTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costTranscript,
    $costPattern,
    $transcriptOptions
)
Assert-Equal -Actual $costTranscriptMatches.Count -Expected 4 -Message 'Cost token rule matches Cost: and Cost-space numeric transcript lines'
Assert-True -Condition (($costTranscriptMatches | ForEach-Object { $_.Value }) -notcontains '10') -Message 'Cost token rule must not color the numeric value as a standalone match'
$costFullTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costTranscript,
    $costFullPattern,
    $transcriptOptions
)
Assert-Equal -Actual $costFullTranscriptMatches.Count -Expected 3 -Message 'Cost full phrase rule matches Cost: 10 and Cost : 10 transcript lines'
Assert-True -Condition (($costFullTranscriptMatches | ForEach-Object { $_.Value }) -contains 'Cost: 10') -Message 'Cost full phrase rule must include Cost: 10 and its numeric value'
Assert-True -Condition (($costFullTranscriptMatches | ForEach-Object { $_.Value }) -contains 'Cost : 10') -Message 'Cost full phrase rule must include Cost : 10 and its numeric value'

foreach ($sample in @('Costs: 1', 'preCost: 1', 'Costume: 10')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $costPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Cost token rule rejects non-matching output: $sample"
}

Write-Host '[PASS] OSPF Cost token rule matches screenshot transcript without coloring numbers'

$routeSectionStart = -1
$routeSectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]ROUTING_TABLE_CODES_AND_METRICS",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $routeSectionStart = $index
        break
    }
}

Assert-True -Condition ($routeSectionStart -ge 0) -Message 'ROUTING_TABLE_CODES_AND_METRICS section must exist'

for ($index = $routeSectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $routeSectionEnd = $index
        break
    }
}

$routeSectionLines = $lines[$routeSectionStart..($routeSectionEnd - 1)]
$routeSectionText = [string]::Join([System.Environment]::NewLine, $routeSectionLines)
$routeMetricRule = @{ Pattern = '\[[0-9]+/[0-9]+\]'; Color = '0000D7FF' }
$routeLegendRuleSpecs = @(
    @{ Pattern = '\bL\x20+-'; Color = '0032CD32' },
    @{ Pattern = '\bC\x20+-'; Color = '00FFFF00' },
    @{ Pattern = '\bS\*?\x20+-'; Color = '0000D7FF' },
    @{ Pattern = '\bR\x20+-'; Color = '00FF00FF' },
    @{ Pattern = '\bI\x20+-'; Color = '0000A5FF' },
    @{ Pattern = '\bM\x20+-'; Color = '00EE82EE' },
    @{ Pattern = '\bB\x20+-'; Color = '000080FF' },
    @{ Pattern = '\bD\x20+-'; Color = '00B469FF' },
    @{ Pattern = '\bEX\x20+-'; Color = '000000FF' },
    @{ Pattern = '\bO\x20+-'; Color = '00FACE87' },
    @{ Pattern = '\bIA\x20+-'; Color = '00C0C0C0' },
    @{ Pattern = '\b(?:N1|E1)\x20+-'; Color = '0000FFFF' },
    @{ Pattern = '\b(?:N2|E2)\x20+-'; Color = '00FFBF00' },
    @{ Pattern = '\b(?:i|su|L1|L2|ia)\x20+-'; Color = '00C1B6FF' },
    @{ Pattern = '(?:\*|U|o|P|H|a|\+|%|p|l)\x20+-'; Color = '00FFFFFF' }
)
$routeEntryRuleSpecs = @(
    @{ Pattern = '^\x20*D\x20+EX(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '000000FF' },
    @{ Pattern = '^\x20*O\x20+IA(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00C0C0C0' },
    @{ Pattern = '^\x20*O\x20+(?:E1|N1)(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '0000FFFF' },
    @{ Pattern = '^\x20*O\x20+(?:E2|N2)(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00FFBF00' },
    @{ Pattern = '^\x20*i\x20+(?:su|L1|L2|ia)(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00C1B6FF' },
    @{ Pattern = '^\x20*(?:i|su|L1|L2|ia)(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00C1B6FF' },
    @{ Pattern = '^\x20*L(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '0032CD32' },
    @{ Pattern = '^\x20*C(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00FFFF00' },
    @{ Pattern = '^\x20*(?:S\*|S)(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*R(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00FF00FF' },
    @{ Pattern = '^\x20*I(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '0000A5FF' },
    @{ Pattern = '^\x20*M(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00EE82EE' },
    @{ Pattern = '^\x20*B(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '000080FF' },
    @{ Pattern = '^\x20*D(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00B469FF' },
    @{ Pattern = '^\x20*O(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*(?:\*|U|o|P|H|a|\+|%|p|l)(?=\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00FFFFFF' }
)
$routeRuleSpecs = @($routeMetricRule) + $routeLegendRuleSpecs + $routeEntryRuleSpecs

Assert-True -Condition (-not $routeSectionText.Contains('\s')) -Message 'Routing table rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $routeSectionText.Contains('00E22B8A')) -Message 'Routing table modifier rules must not use the low-contrast purple color'
foreach ($routeRule in $routeRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($routeRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $routeRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $routeSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Routing table rule has exact pattern and color: $($routeRule.Pattern)"
}

$routeCodeColorPairs = @(
    @{ Name = 'L'; Legend = 0; Entries = @(6) },
    @{ Name = 'C'; Legend = 1; Entries = @(7) },
    @{ Name = 'S/S*'; Legend = 2; Entries = @(8) },
    @{ Name = 'R'; Legend = 3; Entries = @(9) },
    @{ Name = 'I'; Legend = 4; Entries = @(10) },
    @{ Name = 'M'; Legend = 5; Entries = @(11) },
    @{ Name = 'B'; Legend = 6; Entries = @(12) },
    @{ Name = 'D'; Legend = 7; Entries = @(13) },
    @{ Name = 'EX'; Legend = 8; Entries = @(0) },
    @{ Name = 'O'; Legend = 9; Entries = @(14) },
    @{ Name = 'IA'; Legend = 10; Entries = @(1) },
    @{ Name = 'N1/E1'; Legend = 11; Entries = @(2) },
    @{ Name = 'N2/E2'; Legend = 12; Entries = @(3) },
    @{ Name = 'IS-IS'; Legend = 13; Entries = @(4, 5) },
    @{ Name = 'Modifiers'; Legend = 14; Entries = @(15) }
)
foreach ($codeColorPair in $routeCodeColorPairs) {
    foreach ($entryIndex in $codeColorPair.Entries) {
        Assert-Equal -Actual $routeLegendRuleSpecs[$codeColorPair.Legend].Color -Expected $routeEntryRuleSpecs[$entryIndex].Color -Message "Legend and route entry colors must agree for $($codeColorPair.Name)"
    }
}

$routeTranscript = @(
    'Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP, I - IGRP',
    '       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area',
    '       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2',
    '       E1 - OSPF external type 1, E2 - OSPF external type 2',
    '       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2',
    '       * - candidate default, U - per-user static route, o - ODR, + - replicated route, l - LISP',
    'D EX 192.168.12.0/24 [170/2560051456] via 192.168.34.4, 01:15:14, Ethernet0/0',
    'C    192.168.23.0/24 is directly connected, Ethernet0/1',
    'L    192.168.23.3/32 is directly connected, Ethernet0/1',
    'D    192.168.24.0/24 [90/307200] via 192.168.34.4, 01:15:19, Ethernet0/0',
    'S*   0.0.0.0/0 [1/0] via 192.168.34.4'
) -join [Environment]::NewLine
$routeTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$metricMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $routeTranscript,
    $routeMetricRule.Pattern,
    $routeTranscriptOptions
)
Assert-Equal -Actual $metricMatches.Count -Expected 3 -Message 'AD/Metric rule must match every screenshot-style route metric'
Assert-True -Condition (($metricMatches | ForEach-Object { $_.Value }) -contains '[170/2560051456]') -Message 'AD/Metric rule must match the long EIGRP external metric'
Assert-True -Condition (($metricMatches | ForEach-Object { $_.Value }) -contains '[90/307200]') -Message 'AD/Metric rule must match the EIGRP metric'
Assert-True -Condition (($metricMatches | ForEach-Object { $_.Value }) -contains '[1/0]') -Message 'AD/Metric rule must match the static default metric'

$legendRuleSamples = @{
    0 = 'Codes: L - local'
    1 = 'Codes: C - connected'
    2 = 'Codes: S - static, S* - candidate static'
    3 = 'Codes: R - RIP'
    4 = 'Codes: I - IGRP'
    5 = 'Codes: M - mobile'
    6 = 'Codes: B - BGP'
    7 = 'Codes: D - EIGRP'
    8 = 'Codes: EX - EIGRP external'
    9 = 'Codes: O - OSPF'
    10 = 'Codes: IA - OSPF inter area'
    11 = 'Codes: N1 - OSPF NSSA external type 1, E1 - OSPF external type 1'
    12 = 'Codes: N2 - OSPF NSSA external type 2, E2 - OSPF external type 2'
    13 = 'Codes: i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2, ia - IS-IS inter area'
    14 = 'Codes: * - candidate default, U - per-user static route, o - ODR, + - replicated route, l - LISP'
}
foreach ($sampleIndex in $legendRuleSamples.Keys) {
    $legendMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $legendRuleSamples[$sampleIndex],
        $routeLegendRuleSpecs[$sampleIndex].Pattern,
        $routeTranscriptOptions
    )
    Assert-True -Condition ($legendMatches.Count -ge 1) -Message "Protocol legend rule must match its Cisco route-code legend: $($legendRuleSamples[$sampleIndex])"
}

$routeEntrySamples = @{
    0 = 'D EX 192.168.12.0/24'
    1 = 'O IA 10.0.0.0/8'
    2 = 'O E1 10.0.0.0/8'
    3 = 'O E2 10.0.0.0/8'
    4 = 'i su 10.0.0.0/8'
    5 = 'su 10.0.0.0/8'
    6 = 'L 192.168.23.3/32'
    7 = 'C 192.168.23.0/24'
    8 = 'S* 0.0.0.0/0'
    9 = 'R 10.0.0.0/8'
    10 = 'I 10.0.0.0/8'
    11 = 'M 10.0.0.0/8'
    12 = 'B 10.0.0.0/8'
    13 = 'D 10.0.0.0/8'
    14 = 'O 10.0.0.0/8'
    15 = 'l 10.0.0.0/8'
}
foreach ($sampleIndex in $routeEntrySamples.Keys) {
    $entryMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $routeEntrySamples[$sampleIndex],
        $routeEntryRuleSpecs[$sampleIndex].Pattern,
        $routeTranscriptOptions
    )
    Assert-Equal -Actual $entryMatches.Count -Expected 1 -Message "Route code rule must match a route line: $($routeEntrySamples[$sampleIndex])"
}

foreach ($falseRouteLine in @(
        'C connected',
        'D EXAMPLE 192.168.12.0/24',
        'show ip route C 192.168.23.0/24',
        '* - candidate default',
        'prefix [170/2560051456]'
    )) {
    foreach ($routeRule in $routeEntryRuleSpecs) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseRouteLine,
                $routeRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Route-specific rule must reject non-route output: $falseRouteLine"
    }
}

foreach ($invalidMetric in @('[170]', '[170/]', '[foo/bar]', '[1/2/3]')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $invalidMetric,
            $routeMetricRule.Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "AD/Metric rule must reject malformed metric: $invalidMetric"
}

Write-Host '[PASS] Routing table protocol codes and AD/Metric values match screenshot-style output without one-letter false positives'

$routeSummarySectionText = Get-IniSectionText -Lines $lines -SectionName 'ROUTING_TABLE_SUMMARY_DISCARD'
$routeSummaryRuleSpecs = @(
    @{ Pattern = 'is\x20+a\x20+summary(?=,\x20+[0-9]{2}:[0-9]{2}:[0-9]{2},\x20+Null[0-9]+\b)'; Color = '00FACE87' },
    @{ Pattern = '\bNull[0-9]+\b'; Color = '0000FFFF' }
)

Assert-True -Condition (-not $routeSummarySectionText.Contains('\s')) -Message 'Route summary rules must use SecureCRT literal-space syntax instead of \s'
foreach ($summaryRule in $routeSummaryRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($summaryRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $summaryRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $routeSummarySectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Route summary rule has exact pattern and color: $($summaryRule.Pattern)"
}

$routeSummaryTranscript = @(
    'O        172.16.0.0/24 is a summary, 00:03:18, Null0',
    'D       192.168.2.0/24 is a summary, 00:06:48, Null42'
) -join [Environment]::NewLine
$routeSummaryTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$summaryMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $routeSummaryTranscript,
    $routeSummaryRuleSpecs[0].Pattern,
    $routeSummaryTranscriptOptions
)
$nullDiscardMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $routeSummaryTranscript,
    $routeSummaryRuleSpecs[1].Pattern,
    $routeSummaryTranscriptOptions
)
Assert-Equal -Actual $summaryMatches.Count -Expected 2 -Message 'Summary rule must match OSPF and EIGRP summary route lines'
Assert-True -Condition (($summaryMatches | ForEach-Object { $_.Value }) -contains 'is a summary') -Message 'Summary rule must highlight the summary phrase'
Assert-Equal -Actual $nullDiscardMatches.Count -Expected 2 -Message 'Null discard rule must match Null0 and multi-digit Null interfaces'
Assert-True -Condition (($nullDiscardMatches | ForEach-Object { $_.Value }) -contains 'Null0') -Message 'Null discard rule must match the OSPF Null0 next hop'
Assert-True -Condition (($nullDiscardMatches | ForEach-Object { $_.Value }) -contains 'Null42') -Message 'Null discard rule must match a numeric Null next hop variant'

foreach ($invalidSummaryLine in @(
        'This is a summary',
        'O        172.16.0.0/24 is a summary, 00:03:18, Null',
        'O        172.16.0.0/24 is a summary, 00:03:18, NullX'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $invalidSummaryLine,
            $routeSummaryRuleSpecs[0].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Summary rule must reject non-route or malformed summary output: $invalidSummaryLine"
}

foreach ($invalidNull in @('Null', 'NullX', 'Null-0', 'Null0X')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $invalidNull,
            $routeSummaryRuleSpecs[1].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Null discard rule must reject malformed Null next hop: $invalidNull"
}

foreach ($nonRouteNullLine in @('This is a summary', 'show ip route', 'Null')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $nonRouteNullLine,
            $routeSummaryRuleSpecs[1].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Null discard rule must reject non-route output without a numeric Null next hop: $nonRouteNullLine"
}

Write-Host '[PASS] OSPF and EIGRP summary routes highlight summary and Null numeric discard next hops'

$networkSectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_NETWORK_TYPE_AND_DR_BDR'
$networkTranscript = @(
    '  Network Type BROADCAST',
    '  Network Type POINT_TO_POINT',
    '  Network Type NON_BROADCAST',
    '  Network Type POINT_TO_MULTIPOINT',
    '  Network Type LOOPBACK',
    '  Network Type NBMA',
    '  State POINT_TO_POINT'
) -join [Environment]::NewLine
$networkPhraseRules = @(
    @{ Pattern = '\bNetwork\x20+Type\x20+BROADCAST\b'; Color = '00FFFF00'; Matches = @('Network Type BROADCAST') },
    @{ Pattern = '\bNetwork\x20+Type\x20+POINT_TO_POINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_POINT') },
    @{ Pattern = '\bNetwork\x20+Type\x20+NON_BROADCAST\b'; Color = '0000A5FF'; Matches = @('Network Type NON_BROADCAST') },
    @{ Pattern = '\bNetwork\x20+Type\x20+POINT_TO_MULTIPOINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_MULTIPOINT') },
    @{ Pattern = '\bNetwork\x20+Type\x20+LOOPBACK\b'; Color = '00FACE87'; Matches = @('Network Type LOOPBACK') },
    @{ Pattern = '\bNetwork\x20+Type\x20+NBMA\b'; Color = '0000A5FF'; Matches = @('Network Type NBMA') },
    @{ Pattern = '\bState\x20+POINT_TO_POINT\b'; Color = '00FFFF00'; Matches = @('State POINT_TO_POINT') }
)
$networkCommandPattern = '\bip\x20+ospf\x20+network\x20+(?:broadcast|point-to-point|non-broadcast|point-to-multipoint)\b'
Assert-True -Condition (-not $networkSectionText.Contains('\s')) -Message 'OSPF network section must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $networkCommandPattern.Contains('\s')) -Message 'ip ospf network rule must use SecureCRT literal-space syntax'
$networkCommandRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($networkCommandPattern) + '",00FFFF00,00000001\s*$'
$networkCommandRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $networkSectionText,
    $networkCommandRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $networkCommandRuleMatches.Count -Expected 1 -Message 'ip ospf network rule has exact yellow color'
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        'ip ospf network point-to-point',
        $networkCommandPattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) -Message 'ip ospf network rule matches command output with literal spaces'
foreach ($networkPhraseRule in $networkPhraseRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($networkPhraseRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $networkPhraseRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Network phrase has exact color: $($networkPhraseRule.Pattern)"
    Assert-True -Condition (-not $networkPhraseRule.Pattern.Contains('\s')) -Message "Network phrase must use SecureCRT literal-space syntax: $($networkPhraseRule.Pattern)"
    foreach ($sample in $networkPhraseRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $networkPhraseRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Network phrase matches screenshot output: $sample"
    }
    $phraseTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkTranscript,
        $networkPhraseRule.Pattern,
        $transcriptOptions
    )
    Assert-Equal -Actual $phraseTranscriptMatches.Count -Expected 1 -Message "Network phrase matches full screenshot transcript: $($networkPhraseRule.Pattern)"
}
$networkRules = @(
    @{ Pattern = '\bBROADCAST\b'; Color = '00FFFF00'; Matches = @('Network Type BROADCAST'); ExpectedCount = 1 },
    @{ Pattern = '\bPOINT_TO_POINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_POINT', 'State POINT_TO_POINT'); ExpectedCount = 2 },
    @{ Pattern = '\bNON_BROADCAST\b'; Color = '0000A5FF'; Matches = @('Network Type NON_BROADCAST'); ExpectedCount = 1 },
    @{ Pattern = '\bPOINT_TO_MULTIPOINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_MULTIPOINT'); ExpectedCount = 1 },
    @{ Pattern = '\bLOOPBACK\b'; Color = '00FACE87'; Matches = @('Network Type LOOPBACK'); ExpectedCount = 1 },
    @{ Pattern = '\bNBMA\b'; Color = '0000A5FF'; Matches = @('Network Type NBMA'); ExpectedCount = 1 }
)

foreach ($networkRule in $networkRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($networkRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $networkRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Network type token has exact color: $($networkRule.Pattern)"

    foreach ($sample in $networkRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $networkRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Network type token matches screenshot output: $sample"
    }

    $networkTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkTranscript,
        $networkRule.Pattern,
        $transcriptOptions
    )
    Assert-Equal -Actual $networkTranscriptMatches.Count -Expected $networkRule.ExpectedCount -Message "Network type token matches expected screenshot transcript count: $($networkRule.Pattern)"
    foreach ($sample in @("prefix$($networkRule.Pattern -replace '\\b', '')", "$($networkRule.Pattern -replace '\\b', '')suffix")) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $networkRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Network type token respects word boundaries: $($networkRule.Pattern)"
    }
}

Write-Host '[PASS] OSPF network type tokens match screenshot transcript without multi-word whitespace rules'

$virtualLinkSectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_VIRTUAL_LINKS'
$virtualLinkRuleSpecs = @(
    @{ Pattern = '\bTransit\x20+area\b'; Color = '00FACE87' },
    @{ Pattern = '\bTransit\x20+area\x20+(?:[0-9]+|(?:[0-9]{1,3}\.){3}[0-9]{1,3})\b,\x20+via\x20+interface\b'; Color = '0000FFFF' },
    @{ Pattern = '\bOSPF_VL[0-9]+\b'; Color = '00B469FF' }
)

Assert-True -Condition (-not $virtualLinkSectionText.Contains('\s')) -Message 'OSPF virtual-link rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $virtualLinkSectionText.Contains('(?<=')) -Message 'OSPF virtual-link rules must not depend on undocumented lookbehind'
Assert-True -Condition (-not $virtualLinkSectionText.Contains('(?=')) -Message 'OSPF virtual-link rules must not depend on lookahead for numeric highlighting'
foreach ($virtualLinkRule in $virtualLinkRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($virtualLinkRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $virtualLinkRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $virtualLinkSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "OSPF virtual-link rule has exact pattern and color: $($virtualLinkRule.Pattern)"
}

$virtualLinkTranscript = @(
    'Virtual Link to router 192.168.101.2 is up',
    'Transit area 1, via interface Ethernet0/1, Cost of using 128',
    'Virtual Link to router 192.168.102.2 is up',
    'Transit area 0.0.0.1, via interface Ethernet0, Cost of using 10'
) -join [Environment]::NewLine
$transitAreaMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $virtualLinkTranscript,
    $virtualLinkRuleSpecs[0].Pattern,
    $transcriptOptions
)
$transitAreaValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $virtualLinkTranscript,
    $virtualLinkRuleSpecs[1].Pattern,
    $transcriptOptions
)
Assert-Equal -Actual $transitAreaMatches.Count -Expected 2 -Message 'Transit area phrase must match integer and dotted-area virtual-link output'
Assert-True -Condition (($transitAreaMatches | ForEach-Object { $_.Value }) -contains 'Transit area') -Message 'Transit area rule must highlight the full phrase'
Assert-Equal -Actual $transitAreaValueMatches.Count -Expected 2 -Message 'Transit area value rule must match integer and dotted area IDs'
Assert-True -Condition (($transitAreaValueMatches | ForEach-Object { $_.Value }) -contains 'Transit area 1, via interface') -Message 'Transit area value rule must match integer area 1'
Assert-True -Condition (($transitAreaValueMatches | ForEach-Object { $_.Value }) -contains 'Transit area 0.0.0.1, via interface') -Message 'Transit area value rule must match dotted area 0.0.0.1'

$virtualLinkIdentifierTranscript = @(
    'Virtual Link OSPF_VL1 to router 192.168.101.2 is up',
    '%OSPF-5-ADJCHG: Process 1, Nbr 192.168.101.2 on OSPF_VL1 from LOADING to FULL, Loading Done'
) -join [Environment]::NewLine
$virtualLinkIdentifierMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $virtualLinkIdentifierTranscript,
    $virtualLinkRuleSpecs[2].Pattern,
    $transcriptOptions
)
Assert-Equal -Actual $virtualLinkIdentifierMatches.Count -Expected 2 -Message 'OSPF virtual-link identifier rule must match show and debug output'
Assert-True -Condition (($virtualLinkIdentifierMatches | ForEach-Object { $_.Value }) -contains 'OSPF_VL1') -Message 'OSPF virtual-link identifier rule must match OSPF_VL1'

$virtualLinkWhitespaceTranscript = "Transit   area   1,   via   interface Ethernet0/1`r`nTransit area 0.0.0.1, via  interface Ethernet0"
$whitespaceAreaValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $virtualLinkWhitespaceTranscript,
    $virtualLinkRuleSpecs[1].Pattern,
    $transcriptOptions
)
Assert-Equal -Actual $whitespaceAreaValueMatches.Count -Expected 2 -Message 'Transit area value rule must match SecureCRT output with variable spaces and CRLF'

foreach ($invalidVirtualLinkLine in @(
        'Transit areas 1, via interface Ethernet0/1',
        'Transit area X, via interface Ethernet0/1',
        'Transit area one, via interface Ethernet0/1',
        'Transit area 0.0.0, via interface Ethernet0',
        'Transit area 1 without an interface',
        'area 1, via interface Ethernet0/1',
        'OSPF area 0.0.0.1, via interface Ethernet0'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $invalidVirtualLinkLine,
            $virtualLinkRuleSpecs[1].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Transit area value rule must reject malformed or incomplete virtual-link output: $invalidVirtualLinkLine"
}

foreach ($nonTransitLine in @(
        'Area 1, via interface Ethernet0/1',
        'Transit region 1, via interface Ethernet0/1'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $nonTransitLine,
            $virtualLinkRuleSpecs[0].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Transit area phrase rule must reject non-Transit output: $nonTransitLine"
}

foreach ($invalidVirtualLinkIdentifier in @('OSPF_VL', 'OSPF_VLX', 'XOSPF_VL1', 'OSPF_VL1X')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $invalidVirtualLinkIdentifier,
            $virtualLinkRuleSpecs[2].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "OSPF virtual-link identifier rule must reject malformed or embedded identifiers: $invalidVirtualLinkIdentifier"
}

Write-Host '[PASS] OSPF virtual-link identifiers, Transit area phrases, and integer/dotted area IDs match Cisco output'

$promptSectionText = Get-IniSectionText -Lines $lines -SectionName 'PROMPTS'
$promptRules = @(
    @{
        Pattern = '^[A-Za-z0-9_.:/-]+\(config(?:-[^)]+)?\)#'
        Color = '0000FFFF'
        Matches = @(
            'Router(config)#',
            'Router(config-if)#',
            'RP/0/RP0/CPU0:router(config)#',
            'RP/0/RP0/CPU0:router(config-if)#'
        )
        Rejects = @('  Router(config)#', 'show ip route #')
    },
    @{
        Pattern = '^[A-Za-z0-9_.:/-]+#'
        Color = '00FFFF00'
        Matches = @('Router#', 'RP/0/RP0/CPU0:router#')
        Rejects = @('  Router#', 'show ip route #')
    },
    @{
        Pattern = '^[A-Za-z0-9_.:/-]+>'
        Color = '00C0C0C0'
        Matches = @('Router>', 'RP/0/RP0/CPU0:router>')
        Rejects = @('  Router>', 'show ip route >')
    }
)

foreach ($promptRule in $promptRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($promptRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $promptRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $promptSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Prompt rule has exact pattern and color: $($promptRule.Pattern)"

    foreach ($sample in $promptRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $promptRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Prompt rule matches Cisco CLI prompt: $sample"
    }

    foreach ($sample in $promptRule.Rejects) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $promptRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Prompt rule rejects non-prompt output: $sample"
    }
}

$promptTranscript = @(
    'R2#conf t',
    'Enter configuration commands, one per line.',
    'R2(config)#end',
    'R2#conf t',
    'Enter configuration commands, one per line.',
    'R2(config)#router ospf 1',
    'R2(config-router)#',
    'R9#',
    'R9(config)#',
    'R9(config-router)#end',
    'RP/0/RP0/CPU0:router#show version',
    'RP/0/RP0/CPU0:router(config-if)#'
) -join [Environment]::NewLine
$lineModeOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$configTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $promptTranscript,
    $promptRules[0].Pattern,
    $lineModeOptions
)
$privilegedTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $promptTranscript,
    $promptRules[1].Pattern,
    $lineModeOptions
)
Assert-Equal -Actual $configTranscriptMatches.Count -Expected 6 -Message 'config prompt rule must match each prompt prefix in a multi-line terminal transcript'
Assert-Equal -Actual $privilegedTranscriptMatches.Count -Expected 4 -Message 'privileged prompt rule must match each prompt prefix in a multi-line terminal transcript'
Assert-Equal -Actual $configTranscriptMatches[2].Value -Expected 'R2(config-router)#' -Message 'config prompt rule must match nested configuration mode'
Assert-Equal -Actual $configTranscriptMatches[4].Value -Expected 'R9(config-router)#' -Message 'config prompt rule must match nested configuration prompt with trailing command'
Assert-Equal -Actual $privilegedTranscriptMatches[2].Value -Expected 'R9#' -Message 'privileged prompt rule must match standalone R9 prompt'

Write-Host '[PASS] Cisco prompt rules match prompt prefixes across a multi-line transcript'

Write-Host '[PASS] Cisco prompt rules match IOS/XR prompts and reject ordinary output'

$redistributionSectionText = Get-IniSectionText -Lines $lines -SectionName 'ROUTING_REDISTRIBUTION'
$redistributionRules = @(
    @{
        Pattern = '^\x20*Redistributing:\x20+(?:(?:External|external)\x20+(?:Routes|routes)\x20+(?:from|From)\x20+)?(?:BGP|bgp|EIGRP|eigrp|EGP|egp|OSPF|ospf|RIP|rip|IS-IS|is-is|ISIS|isis|IGRP|igrp|hello|Hello|connected|Connected|static|Static)(?:\x20+[0-9]+)?(?:\x20*,\x20*(?:BGP|bgp|EIGRP|eigrp|EGP|egp|OSPF|ospf|RIP|rip|IS-IS|is-is|ISIS|isis|IGRP|igrp|hello|Hello|connected|Connected|static|Static)(?:\x20+[0-9]+)?)*\x20*$'
        Color = '00B469FF'
        Matches = @(
            'Redistributing: ospf 1',
            ' Redistributing: eigrp 1, rip',
            'Redistributing: bgp 65000, connected',
            'Redistributing: isis 1',
            'Redistributing: static',
            'Redistributing: egp 1',
            'Redistributing: hello'
        )
        Rejects = @(
            'Routing Protocol is "ospf 1"',
            'redistribute ospf 1',
            'Not Redistributing: ospf 1',
            'Redistributing: eigrp 1, learned from neighbor'
        )
    },
    @{
        Pattern = '^\x20+(?:BGP|bgp|EIGRP|eigrp|EGP|egp|OSPF|ospf|RIP|rip|IS-IS|is-is|ISIS|isis|IGRP|igrp|hello|Hello|connected|Connected|static|Static)(?:\x20+[0-9]+)?\x20*,\x20+includes\x20+subnets\x20+in\x20+redistribution\b'
        Color = '00B469FF'
        Matches = @(
            '    eigrp 1, includes subnets in redistribution',
            '  rip, includes subnets in redistribution',
            '    connected, includes subnets in redistribution'
        )
        Rejects = @(
            'eigrp 1, includes subnets in redistribution',
            '    eigrp 1, learned from neighbor',
            '    eigrp 1, includes subnets'
        )
    },
    @{
        Pattern = '^\x20*Redistributing:\x20+External\x20+Routes\x20+from\b'
        Color = '00EE82EE'
        Matches = @('Redistributing: External Routes from', '  Redistributing: External Routes from')
        Rejects = @('External Routes from', 'Route: External Routes from')
    },
    @{
        Pattern = '^\x20*Redistributing:'
        Color = '00FACE87'
        Matches = @('Redistributing: ospf 1', '    Redistributing: eigrp 1, rip')
        Rejects = @('Not Redistributing: ospf 1', 'redistribute: ospf 1')
    }
)

foreach ($redistributionRule in $redistributionRules) {
    Assert-True -Condition (-not $redistributionRule.Pattern.Contains('\s')) -Message "Redistribution rule must use SecureCRT literal-space syntax: $($redistributionRule.Pattern)"
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($redistributionRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $redistributionRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $redistributionSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Redistribution rule has exact pattern and color: $($redistributionRule.Pattern)"

    foreach ($sample in $redistributionRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $redistributionRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Redistribution rule matches Cisco output: $sample"
    }

    foreach ($sample in $redistributionRule.Rejects) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $redistributionRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Redistribution rule rejects non-redistribution output: $sample"
    }
}

$redistributionTranscript = @(
    'Routing Protocol is "ospf 1"',
    ' Redistributing: External Routes from',
    '    eigrp 1, includes subnets in redistribution',
    'Routing Protocol is "eigrp 1"',
    ' Redistributing: ospf 1',
    'Routing Protocol is "rip"',
    ' Redistributing: eigrp 1, rip',
    ' Redistributing: bgp 65000, connected',
    ' Redistributing: eigrp 1, learned from neighbor'
) -join [Environment]::NewLine
$redistributionTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$singleLineMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $redistributionTranscript,
    $redistributionRules[0].Pattern,
    $redistributionTranscriptOptions
)
$continuationMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $redistributionTranscript,
    $redistributionRules[1].Pattern,
    $redistributionTranscriptOptions
)
$externalRoutesMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $redistributionTranscript,
    $redistributionRules[2].Pattern,
    $redistributionTranscriptOptions
)
Assert-Equal -Actual $singleLineMatches.Count -Expected 3 -Message 'single-line redistribution sources match OSPF, EIGRP/RIP, and BGP/connected forms'
Assert-Equal -Actual $continuationMatches.Count -Expected 1 -Message 'indented OSPF redistribution continuation matches includes-subnets form'
Assert-Equal -Actual $externalRoutesMatches.Count -Expected 1 -Message 'OSPF External Routes from phrase matches in redistribution context'

Write-Host '[PASS] show ip protocols redistribution rules match OSPF, EIGRP, RIP, and other source protocols'

$distanceSectionText = Get-IniSectionText -Lines $lines -SectionName 'ROUTING_PROTOCOL_DISTANCE'
$distanceRules = @(
    @{
        Pattern = '^\x20*Distance:\x20+internal\x20+[0-9]+\x20+external\x20+[0-9]+\x20*$'
        Color = '0000D7FF'
        Matches = @(
            'Distance: internal 90 external 170',
            ' Distance: internal 5 external 255'
        )
        Rejects = @(
            'Distance: internal 90',
            'Distance: internal ninety external 170',
            'distance: internal 90 external 170',
            'Administrative Distance: internal 90 external 170'
        )
    },
    @{
        Pattern = '^\x20*Distance:\x20+\(default\x20+is\x20+[0-9]+\)\x20*$'
        Color = '0000D7FF'
        Matches = @(
            'Distance: (default is 120)',
            ' Distance: (default is 110)',
            '   Distance: (default is 160)'
        )
        Rejects = @(
            'Gateway Distance Last Update',
            'Distance: default is 120',
            'Distance: (default is unknown)',
            'distance: (default is 120)',
            'Administrative Distance: (default is 120)'
        )
    }
)

Assert-True -Condition (-not $distanceSectionText.Contains('\s')) -Message 'Distance rules must use SecureCRT literal-space syntax instead of \s'
foreach ($distanceRule in $distanceRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($distanceRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $distanceRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $distanceSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Distance rule has exact pattern and color: $($distanceRule.Pattern)"

    foreach ($sample in $distanceRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $distanceRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Distance rule matches Cisco output: $sample"
    }

    foreach ($sample in $distanceRule.Rejects) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $distanceRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Distance rule rejects non-distance output: $sample"
    }
}

$distanceTranscript = @(
    'Routing Protocol is "eigrp 1"',
    ' Distance: internal 90 external 170',
    'Routing Protocol is "rip"',
    ' Distance: (default is 120)',
    'Routing Protocol is "ospf 1"',
    ' Distance: (default is 110)',
    'Routing Protocol is "odr"',
    ' Distance: (default is 160)',
    ' Gateway Distance Last Update'
) -join [Environment]::NewLine
$distanceTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$internalExternalMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $distanceTranscript,
    $distanceRules[0].Pattern,
    $distanceTranscriptOptions
)
$defaultDistanceMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $distanceTranscript,
    $distanceRules[1].Pattern,
    $distanceTranscriptOptions
)
Assert-Equal -Actual $internalExternalMatches.Count -Expected 1 -Message 'EIGRP internal/external distance rule must match the Cisco output line'
Assert-Equal -Actual $defaultDistanceMatches.Count -Expected 3 -Message 'default distance rule must match RIP, OSPF, and ODR output lines'
Assert-Equal -Actual $internalExternalMatches[0].Value -Expected ' Distance: internal 90 external 170' -Message 'internal/external rule must include both numeric distance values'
Assert-True -Condition (($defaultDistanceMatches | ForEach-Object { $_.Value }) -contains ' Distance: (default is 120)') -Message 'default distance rule must include the RIP distance value'
Assert-True -Condition (($defaultDistanceMatches | ForEach-Object { $_.Value }) -contains ' Distance: (default is 110)') -Message 'default distance rule must include the OSPF distance value'
Assert-True -Condition (($defaultDistanceMatches | ForEach-Object { $_.Value }) -contains ' Distance: (default is 160)') -Message 'default distance rule must include the ODR distance value'

Write-Host '[PASS] show ip protocols distance values match EIGRP internal/external and default-distance forms without header false positives'

$bgpRouteSectionText = Get-IniSectionText -Lines $lines -SectionName 'BGP_SHOW_IP'
$bgpRouteRuleSpecs = @(
    @{ Pattern = '^\x20*[*sdhri>Smbxfa]+\x20*(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}\x20+.*$'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*[*sdhrSmbxfa]?>(?:\x20*)?i(?=\x20*(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00EE82EE' },
    @{ Pattern = '^\x20*Origin\x20+codes:\x20+i\x20+-'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Network\x20+Next\x20+Hop\x20+Metric(?=\x20+LocPrf\b)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Network\x20+Next\x20+Hop\x20+Metric\x20+LocPrf(?=\x20+Weight\b)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Network\x20+Next\x20+Hop\x20+Metric\x20+LocPrf\x20+Weight(?=\x20+Path\b)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Network\x20+Next\x20+Hop\x20+Metric\x20+LocPrf\x20+Weight\x20+Path(?=\x20*$)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*[*sdhrSmbxfa]?>(?=(?:\x20*i)?\x20*(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '0032CD32' },
    @{ Pattern = '^\x20*[*]?r(?=>(?:\x20*i)?\x20*(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b|\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '000000FF' },
    @{ Pattern = '^\x20*\*(?=(?:[>rSdhmbxfa]\x20*)?(?:i\x20*)?\x20*(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?\b)'; Color = '00FFFF00' }
)
Assert-True -Condition (-not $bgpRouteSectionText.Contains('\s')) -Message 'BGP route rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $bgpRouteSectionText.Contains('(?<=')) -Message 'BGP route rules must not depend on lookbehind'
foreach ($bgpRule in $bgpRouteRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($bgpRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $bgpRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpRouteSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "BGP show-ip rule has exact pattern and color: $($bgpRule.Pattern)"
}

$bgpRouteTranscript = @(
    'Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,',
    '              r RIB-failure, S Stale, m multipath, b backup-path',
    'Origin codes: i - IGP, e - EGP, ? - incomplete',
    '      Network          Next Hop            Metric LocPrf Weight  Path',
    '*>i10.1.1.0/24      192.168.1.2              0             0 65536 i',
    'r>i 4.4.4.4/32      1.1.1.1                 0 0 100 0 1 i',
    '*  10.100.0.0/16    172.16.14.109         2309             0 200 300 e',
    '>  10.102.0.0/16    172.16.14.108         1388             0 100 e'
) -join [Environment]::NewLine
$bgpTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$routeValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpRouteTranscript,
    $bgpRouteRuleSpecs[0].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $routeValueMatches.Count -Expected 4 -Message 'BGP route value rule matches all screenshot-style route rows'
$ibgpMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpRouteTranscript,
    $bgpRouteRuleSpecs[1].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $ibgpMatches.Count -Expected 2 -Message 'iBGP status i rule matches *>i and r>i route status forms'
Assert-True -Condition (($ibgpMatches | ForEach-Object { $_.Value }) -contains '*>i') -Message 'iBGP status i rule matches the compact *>i route prefix'
Assert-True -Condition (($ibgpMatches | ForEach-Object { $_.Value }) -contains 'r>i') -Message 'iBGP status i rule matches the spaced r>i route prefix'
$originLegendMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpRouteTranscript,
    $bgpRouteRuleSpecs[2].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $originLegendMatches.Count -Expected 1 -Message 'Origin legend i rule matches only the Origin codes legend'
Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
        '*>i10.1.1.0/24',
        $bgpRouteRuleSpecs[2].Pattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) -Message 'Origin legend i rule does not consume route-line iBGP status'
$metricHeaderPatterns = $bgpRouteRuleSpecs[3..6].Pattern
foreach ($metricHeaderPattern in $metricHeaderPatterns) {
    $headerMatches = [System.Text.RegularExpressions.Regex]::Matches(
        ($bgpRouteTranscript -split [Environment]::NewLine)[3],
        $metricHeaderPattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $headerMatches.Count -Expected 1 -Message "Metric/LocPrf/Weight/Path header rule matches the Cisco header: $metricHeaderPattern"
}
$statusRuleSpecs = @(
    @{ Name = 'best >'; Pattern = $bgpRouteRuleSpecs[7].Pattern; Color = '0032CD32'; ExpectedCount = 3 },
    @{ Name = 'RIB-failure r'; Pattern = $bgpRouteRuleSpecs[8].Pattern; Color = '000000FF'; ExpectedCount = 1 },
    @{ Name = 'valid *'; Pattern = $bgpRouteRuleSpecs[9].Pattern; Color = '00FFFF00'; ExpectedCount = 2 }
)
foreach ($statusRule in $statusRuleSpecs) {
    $statusMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpRouteTranscript,
        $statusRule.Pattern,
        $bgpTranscriptOptions
    )
    Assert-Equal -Actual $statusMatches.Count -Expected $statusRule.ExpectedCount -Message "$($statusRule.Name) rule matches only BGP route status positions"
    foreach ($falseStatusSample in @(
            'show ip bgp > 10.1.1.0/24',
            'Status codes: * valid',
            'prefix r 10.1.1.0/24',
            '* - candidate default'
        )) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseStatusSample,
                $statusRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "$($statusRule.Name) rule rejects non-route false positive: $falseStatusSample"
    }
}
$routeRuleOrderText = $bgpRouteSectionText
Assert-True -Condition ($routeRuleOrderText.IndexOf($bgpRouteRuleSpecs[1].Pattern) -lt $routeRuleOrderText.IndexOf($bgpRouteRuleSpecs[2].Pattern)) -Message 'iBGP route rule must precede the origin legend rule'
Write-Host '[PASS] BGP show-ip status, origin, and metric fields match Cisco route output without one-character false positives'

$bgpSummarySectionText = Get-IniSectionText -Lines $lines -SectionName 'BGP_SHOW_IP_SUMMARY'
$bgpSummaryRuleSpecs = @(
    @{ Pattern = '^\x20*BGP\x20+router\x20+identifier\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+local\x20+AS\x20+number\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*BGP\x20+router\x20+identifier\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+local\x20+AS\x20+number\b'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Neighbor\x20+V\x20+AS\x20+MsgRcvd\x20+MsgSent\x20+TblVer\x20+InQ\x20+OutQ\x20+Up/Down\x20+State(?:/PfxRcd)?\x20*$'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Neighbor\x20+V(?=\x20+AS\x20+MsgRcvd\b)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Neighbor\x20+V\x20+AS(?=\x20+MsgRcvd\b)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Neighbor\x20+V\x20+AS\x20+MsgRcvd\x20+MsgSent\x20+TblVer\x20+InQ\x20+OutQ\x20+Up/Down\x20+State(?=\x2fPfxRcd\b|\x20*$)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*/PfxRcd\x20*$'; Color = '00FACE87' },
    @{ Pattern = '^\x20*\*?(?:[0-9]{1,3}\.){3}[0-9]{1,3}\x20+[0-9]+\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\x20+[0-9]+\x20+[0-9]+\x20+[0-9]+\x20+[0-9]+(?:\x20+[0-9]+)?\x20+(?:[0-9]{2}:[0-9]{2}:[0-9]{2}|never)\x20+(?:[0-9]+|Idle(?:\x20+\(Admin\))?|Active|Connect|OpenSent|OpenConfirm|Established|PfxRcd)\x20*$'; Color = '0000D7FF' }
)
Assert-True -Condition (-not $bgpSummarySectionText.Contains('\s')) -Message 'BGP summary rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $bgpSummarySectionText.Contains('(?<=')) -Message 'BGP summary rules must not depend on lookbehind'
foreach ($summaryRule in $bgpSummaryRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($summaryRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $summaryRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpSummarySectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "BGP summary rule has exact pattern and color: $($summaryRule.Pattern)"
}

$bgpSummaryTranscript = @(
    'BGP router identifier 192.168.3.1, local AS number 45000',
    'BGP table version is 1, main routing table version 1',
    'Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd',
    '*192.168.3.2    4 50000       2       2        0    0    0 00:00:37        0',
    'BGP router identifier 172.17.1.99, local AS number 1.2',
    'Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State',
    '192.168.1.2     4         1.0       9       9        1    0    0 00:04:13      0',
    '/PfxRcd',
    '10.1.1.1 4 2 5 6 0 0 00:52:39 2'
) -join [Environment]::NewLine
$summaryLocalValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[0].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryLocalValueMatches.Count -Expected 2 -Message 'Summary local AS value rule matches asplain and asdot 2/4-byte ASNs'
$summaryLocalTitleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[1].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryLocalTitleMatches.Count -Expected 2 -Message 'Summary local AS title rule matches both Cisco local-AS sentence forms'
Assert-True -Condition (($summaryLocalTitleMatches | ForEach-Object { $_.Value }) -notcontains 'BGP router identifier 192.168.3.1, local AS number 45000') -Message 'Summary local AS title rule stops before the ASN value'
$summaryHeaderMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[2].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryHeaderMatches.Count -Expected 2 -Message 'Summary header rule matches State/PfxRcd and State variants'
foreach ($headerRule in $bgpSummaryRuleSpecs[3..5]) {
    $headerMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpSummaryTranscript,
        $headerRule.Pattern,
        $bgpTranscriptOptions
    )
    Assert-Equal -Actual $headerMatches.Count -Expected 2 -Message "Summary $($headerRule.Pattern) title rule matches both header variants"
}
$summaryWrapMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[6].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryWrapMatches.Count -Expected 1 -Message 'Summary wrapped /PfxRcd title rule matches Cisco line variant'
$summaryValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[7].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryValueMatches.Count -Expected 3 -Message 'Summary value rule matches standard, asdot, and IOL compact rows'
Assert-True -Condition (($summaryValueMatches | ForEach-Object { $_.Value }) -contains '*192.168.3.2    4 50000       2       2        0    0    0 00:00:37        0') -Message 'Summary value rule includes dynamic-neighbor rows'
Assert-True -Condition (($summaryValueMatches | ForEach-Object { $_.Value }) -contains '10.1.1.1 4 2 5 6 0 0 00:52:39 2') -Message 'Summary value rule includes the screenshot-style compact row'
foreach ($falseSummarySample in @(
        'V AS MsgRcvd MsgSent',
        'BGP router identifier 192.168.3.1, local AS number not-an-asn',
        'not-a-neighbor 4 50000 2 2 0 0 0 00:00:37 0',
        '192.168.3.2 4 50000 2 2 0 0 0 00:00:37 Unknown'
    )) {
    foreach ($summaryRule in $bgpSummaryRuleSpecs[0,2,3,4,5,7]) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseSummarySample,
                $summaryRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Summary rule rejects malformed or non-summary text: $falseSummarySample"
    }
}
Write-Host '[PASS] BGP summary local-AS, V/AS/State headers, and neighbor values match Cisco output without malformed-row false positives'

$bgpNeighborSectionText = Get-IniSectionText -Lines $lines -SectionName 'BGP_SHOW_IP_NEIGHBORS'
$bgpNeighborRuleSpecs = @(
    @{ Pattern = '^\x20*BGP\x20+neighbor\x20+is\x20+\*?(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+remote\x20+AS\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*BGP\x20+neighbor\x20+is\x20+\*?(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+remote\x20+AS\b'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Last\x20+read\x20+[0-9]{2}:[0-9]{2}:[0-9]{2}\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*Last\x20+read\b'; Color = '00FACE87' },
    @{ Pattern = '(?:^\x20*|\x20+)last\x20+write\x20+[0-9]{2}:[0-9]{2}:[0-9]{2}\b'; Color = '0000D7FF' },
    @{ Pattern = '(?:^\x20*|\x20+)last\x20+write\b'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Last\x20+written\x20+[0-9]{2}:[0-9]{2}:[0-9]{2}\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*Last\x20+written\b'; Color = '00FACE87' },
    @{ Pattern = '(?:^\x20*|\x20+)hold\x20+time\x20+(?:is|=)\x20+[0-9]+\b'; Color = '0000D7FF' },
    @{ Pattern = '(?:^\x20*|\x20+)hold\x20+time\x20+(?:is\b|=)'; Color = '00FACE87' },
    @{ Pattern = '(?:^\x20*|\x20+)keepalive\x20+interval\x20+(?:is|=)\x20+[0-9]+\x20+seconds\b'; Color = '0000D7FF' },
    @{ Pattern = '(?:^\x20*|\x20+)keepalive\x20+interval\x20+(?:is\b|=)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*NEXT_HOP\x20+is\x20+always\x20+this\x20+router\x20+for\x20+eBGP\x20+paths\x20*$'; Color = '00FFFF00' }
)
Assert-True -Condition (-not $bgpNeighborSectionText.Contains('\s')) -Message 'BGP neighbor rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $bgpNeighborSectionText.Contains('(?<=')) -Message 'BGP neighbor rules must not depend on lookbehind'
foreach ($neighborRule in $bgpNeighborRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($neighborRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $neighborRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpNeighborSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "BGP neighbor rule has exact pattern and color: $($neighborRule.Pattern)"
}

$bgpNeighborTranscript = @(
    'BGP neighbor is 1.1.1.1,  remote AS 2, internal link',
    'BGP neighbor is *172.16.10.2,  remote AS 45000, external link',
    '  Last read 00:00:39, last write 00:00:00, hold time is 180, keepalive interval is 60 seconds',
    '  Last read 00:00:28, hold time = 90, keepalive interval = 30 seconds',
    '  Last written 00:00:28, keepalive timer expiry due 00:00:31',
    ' NEXT_HOP is always this router for eBGP paths',
    '    NEXT_HOP   is  always   this router  for   eBGP   paths   '
) -join [Environment]::NewLine
$neighborRemoteValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpNeighborTranscript,
    $bgpNeighborRuleSpecs[0].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $neighborRemoteValueMatches.Count -Expected 2 -Message 'Neighbor remote-AS value rule matches 2-byte and 4-byte ASN forms'
$neighborRemoteTitleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpNeighborTranscript,
    $bgpNeighborRuleSpecs[1].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $neighborRemoteTitleMatches.Count -Expected 2 -Message 'Neighbor remote-AS title rule matches single and double-space Cisco variants'
Assert-True -Condition (($neighborRemoteTitleMatches | ForEach-Object { $_.Value }) -notcontains 'BGP neighbor is 1.1.1.1,  remote AS 2') -Message 'Neighbor remote-AS title rule stops before the ASN value'
$lastReadMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[2].Pattern, $bgpTranscriptOptions)
$lastWriteMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[4].Pattern, $bgpTranscriptOptions)
$lastWrittenMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[6].Pattern, $bgpTranscriptOptions)
Assert-Equal -Actual $lastReadMatches.Count -Expected 2 -Message 'Last read value rule matches IOS timer lines'
Assert-Equal -Actual $lastWriteMatches.Count -Expected 1 -Message 'last write value rule matches the IOS lowercase variant'
Assert-Equal -Actual $lastWrittenMatches.Count -Expected 1 -Message 'Last written value rule matches the alternate Cisco wording'
$holdValueMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[8].Pattern, $bgpTranscriptOptions)
$holdTitleMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[9].Pattern, $bgpTranscriptOptions)
$keepaliveValueMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[10].Pattern, $bgpTranscriptOptions)
$keepaliveTitleMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[11].Pattern, $bgpTranscriptOptions)
$nextHopMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[12].Pattern, $bgpTranscriptOptions)
Assert-Equal -Actual $holdValueMatches.Count -Expected 2 -Message 'hold-time value rule matches is and equals IOS variants'
Assert-Equal -Actual $holdTitleMatches.Count -Expected 2 -Message 'hold-time title rule matches is and equals IOS variants'
Assert-Equal -Actual $keepaliveValueMatches.Count -Expected 2 -Message 'keepalive value rule matches interval is/equals and seconds'
Assert-Equal -Actual $keepaliveTitleMatches.Count -Expected 2 -Message 'keepalive title rule matches interval is/equals variants'
Assert-True -Condition (($keepaliveValueMatches | ForEach-Object { $_.Value }) -contains 'keepalive interval is 60 seconds') -Message 'keepalive value rule includes the seconds phrase and numeric value'
Assert-Equal -Actual $nextHopMatches.Count -Expected 2 -Message 'NEXT_HOP rule matches leading and multiple-space Cisco variants'
Assert-True -Condition (($nextHopMatches | ForEach-Object { $_.Value }) -contains ' NEXT_HOP is always this router for eBGP paths') -Message 'NEXT_HOP rule matches the official Cisco phrase'
Assert-True -Condition (($nextHopMatches | ForEach-Object { $_.Value }) -contains '    NEXT_HOP   is  always   this router  for   eBGP   paths   ') -Message 'NEXT_HOP rule consumes the complete phrase with trailing spaces'
foreach ($falseNeighborSample in @(
        'Neighbor 1.1.1.1, remote AS 2',
        'BGP neighbor is 1.1.1.1, remote AS unknown, internal link',
        'Last read never',
        'last write 00:00',
        'hold time is many',
        'keepalive interval is 60 sec'
    )) {
    foreach ($neighborRule in $bgpNeighborRuleSpecs[0,2,4,6,8,10]) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseNeighborSample,
                $neighborRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Neighbor value rule rejects malformed or incomplete output: $falseNeighborSample"
    }
}
foreach ($falseNextHopSample in @(
        ' NEXT_HOP is always this router for eBGP',
        ' NEXT_hop is always this router for eBGP paths'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $falseNextHopSample,
            $bgpNeighborRuleSpecs[12].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "NEXT_HOP rule rejects incomplete or case-mismatched output: $falseNextHopSample"
}
Write-Host '[PASS] BGP neighbor remote-AS, read/write, hold-time, keepalive, seconds, and NEXT_HOP rules match IOS variants without malformed values'
