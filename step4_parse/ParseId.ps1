<#
.DESCRIPTION
parse a file by id, writing from token_*_id.csv to parse_*_id.json

.PARAMETER Id
the ID of the file to process

.PARAMETER CopyToExpected
if set, also copy the file to the "expected" folder
#>

param (
    [Parameter(Mandatory = $true)]
    [int]$Id,
    [switch]$CopyToExpected
)

# find file in step3_tokenize\data
$inFile = Get-Item -Path "$PSScriptRoot\..\step3_tokenize\data\tokens_*_$Id.csv"
Write-Host "Read $($inFile.FullName)"

[string]$outDir = "$PSScriptRoot\data"
mkdir -Force $outDir | Out-Null

[string]$outFilePath = $inFile.Name -replace "^tokens_", "parse_"
$outFilePath = $outFilePath -replace "\.csv$", ".json"
$outFilePath = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFilePath)

. $PSScriptRoot\ParseFile.ps1 -InFile $inFile |
    ConvertTo-Json -Depth 100 |
    Set-Content -Path $outFilePath -Encoding UTF8

Write-Host "Write $outFilePath"

if ($CopyToExpected) {
    [string]$expectedDir = "$PSScriptRoot\expected"
    mkdir -Force $expectedDir | Out-Null

    $inFile = Get-Item -Path "$PSScriptRoot\..\step3_tokenize\data\tokens_*_$Id.csv"
    [string]$expectedFilePath = $inFile.Name -replace "^tokens_", "parse_"
    $expectedFilePath = $expectedFilePath -replace "\.csv$", ".json"
    $expectedFilePath = Join-Path -Path $expectedDir -ChildPath (Split-Path -Leaf $expectedFilePath)

    . $PSScriptRoot\ParseFile.ps1 -InFile $inFile |
        ConvertTo-Json -Depth 100 |
        Set-Content -Path $expectedFilePath -Encoding UTF8

    Write-Host "Write $expectedFilePath"
}