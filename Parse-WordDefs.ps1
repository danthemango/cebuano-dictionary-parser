# .Description
# accept an array of tokens, and then groups them by word and tries Parse-WordDef for each
# note: the order of tokens within each word matters
# .EXAMPLE
# $tokens = Import-Csv .\tokenlist.csv
# .\Parse-WordDefs.ps1 -Tokens $tokens
param (
    # [Parameter(Mandatory=$true)]
    $Tokens = (Import-Csv .\tokenlist.csv)
)
$Tokens | Group-Object Word | ForEach-Object { .\Parse-WordDef.ps1 -Tokens $_.Group }
