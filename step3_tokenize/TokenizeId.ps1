<#
.DESCRIPTION
tokenize a file by id, writing from para_letter_id.xml to token_letter_id.xml
#>
param (
    [Parameter(Mandatory=$True)]
    [int]$Id
)

# find file in step2_split_paras\data
$inFile = Get-Item -Path  "$PSScriptRoot\..\step2_split_paras\data\para_*_$Id.xml"
Write-Host "Read $($inFile.FullName)"
[string]$outDir = "$PSScriptRoot\data"
[string]$outFilePath = $inFile.Name -replace "para_", "tokens_"
$outFilePath = $outFilePath -replace ".xml$", ".csv"
$outFilePath = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFilePath)

if (-Not (Test-Path $inFile)) {
    throw "Couldn't find file $inFile"
}
. $PSScriptRoot\TokenizeFile.ps1 -InFile $inFile | Export-Csv -Path $outFilePath -NoTypeInformation
Write-Host "Write $($outFilePath)"