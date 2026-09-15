<#
    tokenize and parse the item by id
#>
param (
    [int]$Id,
    [switch]$CopyToExpected
)

. $PSScriptRoot\step3_tokenize\TokenizeId.ps1 -Id $Id -CopyToExpected:$CopyToExpected
. $PSScriptRoot\step4_parse\ParseId.ps1 -Id $Id -CopyToExpected:$CopyToExpected
