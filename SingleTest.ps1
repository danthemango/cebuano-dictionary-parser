<#
.DESCRIPTION
This file is just for debugging a single definition
#>
$id = 25
. $PSScriptRoot\step3_tokenize\TokenizeId.ps1 -Id $id -CopyToExpected
. $PSScriptRoot\step4_parse\ParseId.ps1 -Id $id -CopyToExpected
