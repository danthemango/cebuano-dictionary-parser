<#
.DESCRIPTION
    Outputs the parse of the token file
#>
param (
    [Parameter(Mandatory=$True)]
    [string]$InFile
)

$Tokens = Import-Csv -Path $InFile

. $PSScriptRoot\Parse.Functions.ps1
Parse-Tokens -Tokens $Tokens
