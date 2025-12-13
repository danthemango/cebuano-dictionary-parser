param (
    [int]$Limit = 100
)

$xml = .\HTML-to-XML.ps1
# tokenize the first 100 word definitions
$tokens = $xml | .\Tokenize.ps1 -Limit $Limit
# save to file for debugging purposes
$tokens | Export-Csv -NoTypeInformation -Encoding utf8 -Path .\tokenlist.csv

$parsed = .\Parse-WordDefs.ps1 -Tokens $tokens

$parsed |
    Where-Object ParseOk -eq $true |
    ConvertTo-Json -Depth 12 |
    Set-Content -Encoding UTF8 -Path "successful-parse.json"

$parsed |
    Where-Object ParseOk -ne $true |
    ConvertTo-Json -Depth 12 |
    Set-Content -Encoding UTF8 -Path "failed-parse.json"