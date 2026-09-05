$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$probe = @(Get-Content (Join-Path $PSScriptRoot 'NAT-Probe4-DashLast.ini'))
$dedicated = @(Get-Content (Join-Path $root 'PNET-Cisco-NAT-V3.ini'))
if (($probe[0..($probe.Count-2)] -join "`n") -cne ($dedicated[0..($dedicated.Count-2)] -join "`n")) {
    throw 'Dedicated list must preserve the native-verified rules exactly'
}
if ($dedicated[-1] -cne 'S:"List Name"=PNET-Cisco-NAT-V3') { throw 'Wrong list name' }
$rules = @($dedicated | ForEach-Object {
    if ($_ -match '^ "([^"]+)",([0-9A-F]{8}),') {
        [pscustomobject]@{Regex=[regex]::new($Matches[1]); Color=$Matches[2]}
    }
})
if ($rules.Count -ne 11 -or $rules[-1].Regex.ToString() -cne '---') { throw 'Wrong count/order' }
$samples = @(Get-Content (Join-Path $PSScriptRoot 'fixtures/NatTranslations.txt'))
$colors = @('00B469FF','0000D7FF','00FFFF00','00FACE87','00EE82EE')
$count = 0
foreach ($n in 0..9) {
    $line = $samples[$n]
    $tokens = if ($n -in @(0,8)) {
        [regex]::Matches($line,'Pro|Inside global|Inside local|Outside local|Outside global')
    } else { [regex]::Matches($line,'\S+') }
    $hits = @{}
    foreach ($rule in $rules) {
        foreach ($hit in $rule.Regex.Matches($line)) {
            if ($hits.ContainsKey($hit.Index)) { throw 'Overlapping diagnostic match' }
            $hits[$hit.Index] = @($hit.Value,$rule.Color)
        }
    }
    if ($hits.Count -ne 5) { throw "Expected five tokens on fixture $n" }
    for ($c=0;$c -lt 5;$c++) {
        $token = $tokens[$c]
        $color = if ($token.Value -eq 'Pro') {'000000FF'} elseif ($token.Value -eq '---') {'00C0C0C0'} else {$colors[$c]}
        $actual=$hits[$token.Index]
        if ($actual[0] -cne $token.Value -or $actual[1] -cne $color) { throw "Wrong fixture $n column $c" }
        $count++
    }
}
Write-Host "[PASS] Native-verified rule parity; --- last; $count fixture spans/colors (.NET semantics only)."
Write-Host '[LIMITATION] Dedicated selection does not prevent non-NAT false positives while this list is active.'
