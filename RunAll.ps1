param (
    [switch]$Force
)

$tokSW = [Diagnostics.Stopwatch]::StartNew()
. $PSScriptRoot\step3_tokenize\TokenizeAll.ps1 -Force:$Force
$tokSW.Stop()

$parseSW = [Diagnostics.Stopwatch]::StartNew()
. $PSScriptRoot\step4_parse\ParseAll.ps1 -Force:$Force
$parseSW.Stop()


.\Calculate.ps1 | Set-Content "Calculation.txt"
Add-Content "Calculation.txt" "Tokenize Time: $($tokSW.Elapsed.ToString())"
Add-Content "Calculation.txt" "Parse Time: $($parseSW.Elapsed.ToString())"

