<#
.DESCRIPTION
tokenize a file by id, writing from para_letter_id.xml to token_letter_id.xml
.PARAMETER Id
the ID of the file to process
.PARAMETER CopyToExpected
if set, also coppy the file to the "expected" folder
#>
param (
    [Parameter(Mandatory=$True)]
    [int]$Id,
    [switch]$CopyToExpected
)

# find file in step2_split_paras\data
$inFile = Get-Item -Path  "$PSScriptRoot\..\step2_split_paras\data\para_*_$Id.xml"
Write-Host "Read $($inFile.FullName)"
[string]$outDir = "$PSScriptRoot\data"
mkdir -Force $outDir | Out-Null
[string]$outFilePath = $inFile.Name -replace "para_", "tokens_"
$outFilePath = $outFilePath -replace ".xml$", ".csv"
$outFilePath = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFilePath)
. $PSScriptRoot\TokenizeFile.ps1 -InFile $inFile | Export-Csv -Path $outFilePath -NoTypeInformation
Write-Host "Write $($outFilePath)"

# TODO pipe to error on failed parse

if ($CopyToExpected) {
    $inFile = Get-Item -Path  "$PSScriptRoot\..\step2_split_paras\data\para_*_$Id.xml"
    [string]$expectedDir = "$PSScriptRoot\expected"
    mkdir -Force $expectedDir | Out-Null
    [string]$expectedFilePath = $inFile.Name -replace "para_", "tokens_"
    Write-Host "Write $($inFile.Name)"
    $expectedFilePath = $expectedFilePath -replace ".xml$", ".csv"
    $expectedFilePath = Join-Path -Path $expectedDir -ChildPath (Split-Path -Leaf $expectedFilePath)
    . $PSScriptRoot\TokenizeFile.ps1 -InFile $inFile | Export-Csv -Path $expectedFilePath -NoTypeInformation
    Write-Host "Write $($expectedFilePath)"
}