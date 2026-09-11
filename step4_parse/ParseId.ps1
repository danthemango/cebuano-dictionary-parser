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
    [switch]$CopyToExpected,
    # if true, only emit errors
    [switch]$Silent,
    # if true, overwrite the data file
    [switch]$Force
)

# [string]$inDir = "$PSScriptRoot\..\step3_tokenize\data"
[string]$outDir = "$PSScriptRoot\data"
mkdir -Force $outDir | Out-Null

$errorDir = "$PSScriptRoot\errors"
mkdir -Force $errorDir | Out-Null

# find file in step3_tokenize\data
$inFile = Get-Item -Path "$PSScriptRoot\..\step3_tokenize\data\tokens_*_$Id.csv"
if (-Not $Silent) { Write-Host "Read $($inFile.FullName)" }

[string]$outDir = "$PSScriptRoot\data"
mkdir -Force $outDir | Out-Null

$outFile = $inFile.FullName -replace "tokens_", "parse_"
$outFile = $outFile -replace "\.csv$", ".json"
$outFile = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFile)

# delete the error file if it exists
$errorFile = $inFile.FullName -replace "tokens_", "error_"
$errorFile = $errorFile -replace "\.csv$", ".txt"
$errorFile = Join-Path -Path $errorDir -ChildPath (Split-Path -Leaf $errorFile)

if (Test-Path $errorFile) {
    Remove-Item -Path $errorFile -Force
}

$parse = . $PSScriptRoot\ParseFile.ps1 -InFile $inFile
if ($parse.Found) {
    if ((-not (Test-Path $outFile)) -or $Force) {
        $parse | ConvertTo-Json -Depth 100 | Set-Content -Path $outFile -Encoding UTF8
        if (-Not $Silent) { Write-Host "Write $outFilePath" }
    } else {
        if (-Not $Silent) { Write-Host "Skip $outFilePath (already exists)" }
    }
} else {
    # delete the outFile if partially created
    if (Test-Path $outFile) {
        Remove-Item $outFile
    }

    $errorMessage = "Failed to parse $inFile"
    $errorMessage += "`n`n"
    $errorMessage += $parse.ParseDiagnostics | ConvertTo-Json -Depth 100
    $errorMessage += "`n`n"
    $errorMessage += $parse | ConvertTo-Json -Depth 100
    # $errorMessage += "`nStack Trace:`n$($_.ScriptStackTrace)"

    # Include input file contents for debugging
    $errorMessage += "`n`nInput File:`n"
    $errorMessage += Get-Content $inFile -Raw

    $errorMessage | Out-File -FilePath $errorFile -Encoding UTF8

    Write-Error "Error parsing $inFile"
}

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

    if (-Not $Silent) { Write-Host "Write $expectedFilePath" }
}