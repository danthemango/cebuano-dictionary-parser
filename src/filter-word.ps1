<#
.SYNOPSIS
    inspect the parsed JSON of word
#>
param (
    [string]$Word = "abága",
    [string]$Path = "out\failed-parse.ndjson"
)

$content = Get-Content -Path $Path
$content -split [System.Environment]::NewLine | ForEach-Object {
    $data = $_ | ConvertFrom-Json
    if ($data.WordDef.Word -eq $Word) {
        $data | ConvertTo-Json -Depth 12
    }
}