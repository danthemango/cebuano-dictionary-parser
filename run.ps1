param (
    [int]$Limit = 100,
    [string]$SearchWord = $null,
    [switch]$Passthru = $false
)

$xml = .\src\HTML-to-XML.ps1 -Path "cebuano-dictionary-fixed.html"

if (Test-Path "out\tokenlist.ndjson") {
    Remove-Item "out\tokenlist.ndjson"
}

if (Test-Path "out\successful-parse.ndjson") {
    Remove-Item "out\successful-parse.ndjson"
}

if (Test-Path "out\failed-parse.ndjson") {
    Remove-Item "out\failed-parse.ndjson"
}

# tokenize to file
$parsed = $xml | .\src\Tokenize.ps1 -Limit $Limit -SearchWord $SearchWord | ForEach-Object {
    .\src\Parse-WordDef.ps1 -Word $_
} | ForEach-Object {
    if ($_.ParseOk) {
        $_ | ConvertTo-Json -Depth 12 -Compress | Add-Content -Encoding UTF8 -Path "out\successful-parse.ndjson"
    } else {
        $_ | ConvertTo-Json -Depth 12 -Compress | Add-Content -Encoding UTF8 -Path "out\failed-parse.ndjson"
    }
    $_
}

$total_num = $parsed.Count
if ($total_num -eq 0) {
    Write-Output "No paragraphs parsed."
    exit
} else {
    $num_success = ($parsed | Where-Object ParseOk -eq $true).Count
    $perc = [math]::Round(100 * ($num_success / $total_num),1)
    Write-Output "parsed $num_success / $total_num ($perc)%"
}

if ($SearchWord -ne $null) {
    $parsed | Where-Object Word -eq $SearchWord | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8BOM ".\out\searchword.json"
    Write-Output "Saved to out\searchword.json"
}

if ($Passthru) {
    return $parsed
}