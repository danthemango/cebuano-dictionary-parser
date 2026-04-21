param (
    [string]$Word = "abága"
)

$content = Get-Content out\failed-parse.ndjson
$content -split [System.Environment]::NewLine | ForEach-Object {
    $data = $_ | ConvertFrom-Json
    if ($data.WordDef.Word -eq $Word) {
        $data | ConvertTo-Json -Depth 12
    }
}