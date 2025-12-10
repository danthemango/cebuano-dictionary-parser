param (
    [string]$inpath = ".\cebuano-dictionary.html"
)

$html = Get-Content $inpath

[xml]$xml = $html
if (-not $xml) {
    throw "could not parse html"
}

$xml