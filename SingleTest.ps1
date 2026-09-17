<#
.DESCRIPTION
This file is just for debugging a single definition
#>
param (
    [switch]$CopyToExpected
)
$id = 42
. $PSScriptRoot\RunId.ps1 -Id $id -CopyToExpected:$CopyToExpected
