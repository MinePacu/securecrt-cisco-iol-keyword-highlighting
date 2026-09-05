param([string]$GitPath = 'git')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$rules = @(Get-Content (Join-Path $PSScriptRoot 'NAT-Matching-Probe2.ini') | ForEach-Object {
    if ($_ -match '^ "([^"]+)",([0-9A-F]{8}),') {
        [pscustomobject]@{ Pattern=$Matches[1]; Color=$Matches[2]; Regex=[regex]::new($Matches[1]) }
    }
})
if ($rules.Count -ne 14) { throw 'Expected 14 probe rules' }
foreach ($rule in $rules) {
    if ($rule.Pattern.Length -gt 256 -or $rule.Pattern -match '\\K|DEFINE|\(\?&') { throw 'Probe must use short non-subroutine rules' }
    $null = & $GitPath -C $root grep --no-index --color=never -h -o -P -e $rule.Pattern -- tests/fixtures/NatProbe2.txt
    if ($LASTEXITCODE -notin @(0,1)) { throw 'PCRE compile/match failure' }
}
$samples = @(Get-Content (Join-Path $PSScriptRoot 'fixtures/NatProbe2.txt'))
$colors = @('00B469FF','0000D7FF','00FFFF00','00FACE87','00EE82EE')
$checked = 0
# The first five lines are supported diagnostic layouts, not all IOS layouts.
for ($line = 0; $line -lt 5; $line++) {
    $text = $samples[$line]
    $expected = @{}
    $tokens = if ($line -eq 0) {
        [regex]::Matches($text, 'Pro|Inside global|Inside local|Outside local|Outside global')
    } else { [regex]::Matches($text, '\S+') }
    for ($c=0; $c -lt $tokens.Count; $c++) {
        $color = if ($tokens[$c].Value -eq '---') { '00C0C0C0' }
            elseif ($line -eq 0 -and $c -eq 0) { '000000FF' } else { $colors[$c] }
        $expected[$tokens[$c].Index] = @($tokens[$c].Value, $color)
    }
    # Candidate-start scan retains the full subject for lookbehind. This tests
    # that model only, NOT SecureCRT's native renderer or matching flags.
    for ($pos=0; $pos -lt $text.Length;) {
        $winner = $null
        foreach ($rule in $rules) {
            $hit = $rule.Regex.Match($text, $pos)
            if ($hit.Success -and $hit.Index -eq $pos) { $winner=@($hit,$rule); break }
        }
        if ($null -eq $winner) {
            if ($expected.ContainsKey($pos)) { throw "Missing token on line $($line+1), offset $pos" }
            $pos++; continue
        }
        $want = $expected[$pos]
        if ($null -eq $want -or $winner[0].Value -cne $want[0] -or $winner[1].Color -cne $want[1]) {
            throw "Wrong span/color on line $($line+1), offset $pos"
        }
        $checked++
        $pos += $winner[0].Length
    }
}
# Deliberately shifted TCP layout may receive partial or no role colors. It must
# never assign a different role merely because an endpoint occupies a known offset.
$shifted = [regex]::Matches($samples[5], '\S+')
foreach ($rule in $rules[7..13]) {
    foreach ($hit in $rule.Regex.Matches($samples[5])) {
        $column = -1
        for ($c=1; $c -lt 5; $c++) { if ($shifted[$c].Index -eq $hit.Index) { $column=$c } }
        if ($column -lt 1 -or $rule.Color -cne $colors[$column]) { throw 'Shifted layout assigned wrong role' }
    }
    foreach ($text in $samples[6..9]) {
        if ($rule.Regex.IsMatch($text)) { throw 'Address-rule false positive in negative fixture' }
    }
}
Write-Host "[PASS] $checked exact spans/colors; short-rule PCRE checks; retained-context candidate scan; shifted-layout and negative checks"
Write-Host '[PENDING] Native SecureCRT: nested lookahead in fixed-width lookbehind, after earlier highlighted fields.'
