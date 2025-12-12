$xml = .\HTML-to-XML.ps1
# tokenize the first 100 word definitions
$tokens = $xml | .\Tokenize.ps1 -Limit 100
# save to file for debugging purposes
$tokens | Export-Csv -NoTypeInformation -Encoding utf8 -Path .\tokenlist.csv

$parsed = .\Parse-WordDefs.ps1 -Tokens $tokens

$parsed | Where-Object ParseOk -eq $true | ConvertTo-Json -Depth 100 | Out-File "successful-parse.json"
$parsed | Where-Object ParseOk -ne $true | ConvertTo-Json -Depth 100 | Out-File "failed-parse.json"