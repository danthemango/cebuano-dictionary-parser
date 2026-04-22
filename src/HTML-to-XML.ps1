<#
.SYNOPSIS
    Converts the HTML doc to xml
.PARAMETER Path
    The path to the html file
#>
param (
    [string]$Path = ".\cebuano-dictionary-fixed.html"
)

$html = Get-Content $path

[xml]$xml = $html
if (-not $xml) {
    throw "could not parse html"
}

$xml