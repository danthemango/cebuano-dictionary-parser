param (
    [switch]$Force
)

.\$PSScriptRoot\step3_tokenize\TokenizeAll.ps1 -Force:$Force
.\$PSScriptRoot\step4_parse\ParseAll.ps1 -Force:$Force

