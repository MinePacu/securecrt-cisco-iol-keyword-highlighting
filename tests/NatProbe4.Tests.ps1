$ErrorActionPreference = 'Stop'
function Read-Rules($name) {
    @(Get-Content (Join-Path $PSScriptRoot $name) | ForEach-Object {
        if ($_ -match '^ "([^"]+)",([A-F0-9]{8}),') {
            [pscustomobject]@{Pattern=$Matches[1];Color=$Matches[2];Raw=$_;Regex=[regex]::new($Matches[1])}
        }
    })
}
$old = @(Read-Rules 'NAT-Probe3-Suffix.ini')
$new = @(Read-Rules 'NAT-Probe4-DashLast.ini')
if ($new.Count -ne 11 -or $new[-1].Pattern -cne '---') { throw 'Wrong rule count/order' }
if (Compare-Object ($old.Raw | Sort-Object) ($new.Raw | Sort-Object)) { throw 'Probe must only reorder existing rules' }
$oldOther = @($old | Where-Object Pattern -cne '---')
if (($oldOther.Raw -join "`n") -cne ($new[0..9].Raw -join "`n")) { throw 'Other rules changed order' }
$line = '--- 211.239.123.254    10.1.1.1           ---                ---'
$addresses = @($new | Where-Object { $_.Pattern.StartsWith('\b(?:[0-9]') })
$want = @('211.239.123.254','10.1.1.1')
for ($i=0;$i -lt 2;$i++) {
    $hit = $addresses[$i].Regex.Match($line)
    if (-not $hit.Success -or $hit.Value -cne $want[$i]) { throw 'Static NAT semantic regression' }
}
Write-Host '[PASS] Exactly one rule moved: --- now follows all four address rules; static address semantics unchanged.'
# Demonstrate, rather than hide, the information lost by suffix-only classification.
$cases = @(
    @{Name='gateway';Text='Gateway of last resort is 192.0.2.1 to network 0.0.0.0'},
    @{Name='ACL';Text='10 permit ip host 192.0.2.1 host 198.51.100.1'},
    @{Name='non-NAT endpoint';Text='Connected to 198.51.100.1:443'},
    @{Name='missing NAT column';Text='icmp 211.239.123.254:39829 10.1.1.1:39829 2.2.2.2:39829'}
)
foreach ($case in $cases) {
    $hits = @($addresses | ForEach-Object {
        $rule=$_
        foreach ($hit in $rule.Regex.Matches($case.Text)) {
            '{0} -> {1}' -f $hit.Value,$rule.Color
        }
    })
    if ($hits.Count -eq 0) { throw "Expected diagnostic counterexample missing: $($case.Name)" }
    Write-Host ('[KNOWN UNSAFE] {0}: {1}' -f $case.Name,($hits -join '; '))
}
Write-Host '[OBSERVED SEPARATELY] User screenshot confirmed ICMP and static NAT with DashLast; this test does not run SecureCRT.'
