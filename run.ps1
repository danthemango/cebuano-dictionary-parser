param (
    [int]$Limit = 100,
    [string]$HtmlPath = "cebuano-dictionary-fixed.html",
    [string]$Searchword = "",
    [switch]$Passthru = $false
)

[xml]$xml = Get-Content -Path $HtmlPath
if (-not $xml) {
    throw "could not parse $HtmlPath as xml"
}

if (Test-Path "out\tokenlist.csv") {
    Remove-Item "out\tokenlist.csv"
}

if (Test-Path "out\successful-parse.ndjson") {
    Remove-Item "out\successful-parse.ndjson"
}

if (Test-Path "out\failed-parse.ndjson") {
    Remove-Item "out\failed-parse.ndjson"
}

# tokenize to file
$parsed = $xml | .\src\Tokenize.ps1 -Limit $Limit -SearchWord $Word | Where-Object {
    # if the searchword is set, filter by word
    return $Searchword -eq "" -or $Searchword -eq $_.Word
} | ForEach-Object {
    $word = $_.Word
    $_.Tokens | ForEach-Object {
        [PSCustomObject]@{
            Word = $word
            Type = $_.Type
            Content = $_.Content
        } | Export-Csv -Encoding utf8BOM -Append -Path "out\tokenlist.csv"
    }
    $_
} | ForEach-Object {
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

# if there's a searchword, output it cleanly for the one word
if ($Searchword -ne "") {
    $parsed | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8BOM ".\out\searchword.json"
    Write-Output "Saved to out\searchword.json"
}

if ($Passthru) {
    return $parsed
}