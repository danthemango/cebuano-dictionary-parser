<#
.DESCRIPTION
    Outputs the parse of the token file
#>
param (
    [Parameter(Mandatory=$True)]
    [string]$InFile
)

$Tokens = Import-Csv -Path $InFile

# select the first CEBWORD token and set it as the 
$firstWordToken = $Tokens | Where-Object { $_.Type -eq "CEBWORD" } | Select-Object -First 1
if ($null -eq $firstWordToken) {
    throw "No CEBWORD token found in the input file."
}

$Word = [PSCustomObject]@{
    Word = $firstWordToken.Content
    Tokens = $Tokens
}

. $PSScriptRoot\Parse.Functions.ps1
Parse -Word $Word
