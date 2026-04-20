param (
    [int]$Limit = 100
)

$xml = .\HTML-to-XML.ps1

if (Test-Path ".\out\tokenlist.ndjson") {
    Remove-Item ".\out\tokenlist.ndjson"
}

if (Test-Path "out\successful-parse.ndjson") {
    Remove-Item "out\successful-parse.ndjson"
}

if (Test-Path "out\failed-parse.ndjson") {
    Remove-Item "out\failed-parse.ndjson"
}

# tokenize to file
$xml | .\Tokenize.ps1 -Limit $Limit | ForEach-Object {
    # export tokens to file
    $_ | ConvertTo-Json -Depth 12 -Compress | Add-Content -Encoding UTF8 -Path "out\tokenlist.ndjson"
    $_
} | ForEach-Object {
    .\Parse-WordDef.ps1 -Tokens $_.Tokens
} | ForEach-Object {
    if ($_.ParseOk) {
        $_ | ConvertTo-Json -Depth 12 -Compress | Add-Content -Encoding UTF8 -Path "out\successful-parse.ndjson"
    } else {
        $_ | ConvertTo-Json -Depth 12 -Compress | Add-Content -Encoding UTF8 -Path "out\failed-parse.ndjson"
    }
}

# $total_num = $parsed.Count
# $num_success = ($parsed | Where-Object ParseOk -eq $true).Count
# $perc = [math]::Round(100 * ($num_success / $total_num),1)
# Write-Output "parsed $num_success / $total_num ($perc)%"

