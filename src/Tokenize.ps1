<#
.Description
    create a stream of tokens for each word definition, based on some established patterns
.PARAMETER inxml
    accept input as xml object piped in, mandatory
.PARAMETER Limit
    limit the number of paragraphs to parse for testing
    set Limit = $null for no limit
.EXAMPLE
    .\HTML-to-XML.ps1 | .\Tokenize.ps1 -Limit 100 | Export-Csv -Encoding utf8 -NoTypeInformation -Path "tokenlist.csv"
.EXAMPLE
    $xml = .\HTML-to-XML.ps1
    $tokens = $xml | .\Tokenize.ps1 -Limit 100
    $tokens | Export-Csv -Encoding utf8 -NoTypeInformation -Path "tokenlist.csv"
#>
param (
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [xml]$xml = $null,
    [Parameter(Mandatory = $true)]
    [int]$Limit = $null,
    [string]$SearchWord = $null
)

. $PSScriptRoot\Tokenize.Functions.ps1

# main
$paragraphs = $xml | Split-Paragraphs

if ($Limit) {
    $paragraphs = $paragraphs | Select-Object -First $Limit
}

if ($SearchWord -ne $null) {
    $paragraphs = $paragraphs | Where-Object {
        $_.tokens.Content -like "*$SearchWord*"
    }
}

$paragraphs | ForEach-Object {
    $_.tokens = $_.tokens | Tokenize
    $cebWords = $_.tokens | Where-Object Type -eq "CEBWORD"
    if ($cebWords.Count -eq 0) {
        $Word = ""
    }
    else {
        $Word = $cebWords[0].Content
    }

    [PSCustomObject]@{
        Word   = $Word
        Tokens = $_.tokens
    }
}