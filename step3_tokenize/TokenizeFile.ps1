<#
.DESCRIPTION
    Outputs the token array for a given xml file
#>
param (
    [Parameter(Mandatory=$True)]
    [string]$InFile
)

[xml]$xml = Get-Content $InFile

$textToken = [PSCustomObject]@{
    Type    = "TEXT"
    Content = $xml.root.innerXml
}

$textToken | Tokenize
