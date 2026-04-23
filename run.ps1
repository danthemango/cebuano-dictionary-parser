param (
    [int]$Limit = 200,
    [string]$HtmlPath = "cebuano-dictionary-fixed.html",
    [string]$Searchword = "",
    [switch]$Passthru = $false
)

[xml]$xml = Get-Content -Path $HtmlPath
if (-not $xml) {
    throw "could not parse $HtmlPath as xml"
}

# tokenize to file
$parsed = $xml | .\src\Tokenize.ps1 -Limit $Limit -SearchWord $Searchword | Where-Object {
    # if the searchword is set, filter by word
    return $Searchword -eq "" -or $Searchword -eq $_.Word
} | ForEach-Object {
    .\src\Parse-WordDef.ps1 -Word $_
}

# write to tokenlist.csv
$parsed | ForEach-Object {
    $word = $_.Word
    $_.Tokens | ForEach-Object {
        [PSCustomObject]@{
            Word = $word
            Type = $_.Type
            Content = $_.Content
        } 
    }
} | Export-Csv -Encoding utf8BOM -Path "out\tokenlist.csv"

# write to successful-parse.json and failed-parse.json
$parsed | Where-Object ParseOk -eq $true | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8BOM -Path "out\successful-parse.json"
$parsed | Where-Object ParseOk -eq $false | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8BOM -Path "out\failed-parse.json"

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