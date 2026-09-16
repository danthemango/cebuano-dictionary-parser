param (
    [switch]$Force
)

Write-Output "Deleting empty files"
Get-ChildItem "step3_tokenize\data" | Where-Object length -eq 0 | Remove-Item

step2_split_paras\fix-typos.ps1

$tokSW = [Diagnostics.Stopwatch]::StartNew()
. $PSScriptRoot\step3_tokenize\TokenizeAll.ps1 -Force:$Force
$tokSW.Stop()

# write some interim results
.\Calculate.ps1 | Set-Content "Calculation.txt"
Add-Content "Calculation.txt" "Tokenize Time: $($tokSW.Elapsed.ToString())"

$parseSW = [Diagnostics.Stopwatch]::StartNew()
. $PSScriptRoot\step4_parse\ParseAll.ps1 -Force:$Force
$parseSW.Stop()

# write final results
.\Calculate.ps1 | Set-Content "Calculation.txt"
Add-Content "Calculation.txt" "Tokenize Time: $($tokSW.Elapsed.ToString())"
Add-Content "Calculation.txt" "Parse Time: $($parseSW.Elapsed.ToString())"

