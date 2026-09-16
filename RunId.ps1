<#
    tokenize and parse the item by id
#>
param (
    [int]$Id,
    [switch]$CopyToExpected
)

. $PSScriptRoot\step2_split_paras\Fix-Typos.ps1
Remove-Item "step4_parse\errors\error_*_$id.txt"
. $PSScriptRoot\step3_tokenize\TokenizeId.ps1 -Id $Id -CopyToExpected:$CopyToExpected
. $PSScriptRoot\step4_parse\ParseId.ps1 -Id $Id -CopyToExpected:$CopyToExpected
