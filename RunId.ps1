<#
    tokenize and parse the item by id
#>
param (
    [int]$Id,
    [switch]$CopyToExpected,
    [switch]$SkipReplacements,
    [switch]$Verbose
)

if (-Not $SkipReplacements) {
    . $PSScriptRoot\step2_split_paras\ReplaceExceptions.ps1
}
Remove-Item "step3_tokenize\errors\error_*_$id.txt"
Remove-Item "step4_parse\errors\error_*_$id.txt"
. $PSScriptRoot\step3_tokenize\TokenizeId.ps1 -Id $Id -CopyToExpected:$CopyToExpected # -Verbose:$Verbose
. $PSScriptRoot\step4_parse\ParseId.ps1 -Id $Id -CopyToExpected:$CopyToExpected -Force -Verbose:$Verbose
