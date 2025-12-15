param (
    [int]$Limit = 100
)

$xml = .\HTML-to-XML.ps1

# tokenize to file
$xml | .\Tokenize.ps1 -Limit $Limit | Export-Csv -NoTypeInformation -Encoding utf8 -Path .\tokenlist.csv
# parse from tokens file
$parsed = .\Parse-WordDefs.ps1 -Tokens (Import-Csv .\tokenlist.csv)

$total_num = $parsed.Count
$num_success = ($parsed | Where-Object ParseOk -eq $true).Count
Write-Output "parsed $($num_success) / $($total_num)"

$parsed |
    Where-Object ParseOk -eq $true |
    ConvertTo-Json -Depth 12 |
    Set-Content -Encoding UTF8 -Path "successful-parse.json"

$parsed |
    Where-Object ParseOk -ne $true |
    ConvertTo-Json -Depth 12 |
    Set-Content -Encoding UTF8 -Path "failed-parse.json"