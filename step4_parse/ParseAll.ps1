param (
    # if true, update the files even if they exist
    [switch]$Force
)

[string]$inDir = "$PSScriptRoot\..\step3_tokenize\data"
[string]$outDir = "$PSScriptRoot\data"
mkdir -Force $outDir | Out-Null

$errorDir = "$PSScriptRoot\errors"
mkdir -Force $errorDir | Out-Null

Get-ChildItem -Path $inDir -Filter "tokens_*.csv" | ForEach-Object {
    $inFile = $_
    # get the Id number from a file with pattern "tokens_[a-z]_[0-9]+.csv"
    $id = [regex]::Match($inFile.Name, 'tokens_[a-z]_(\d+)\.csv').Groups[1].Value
    . $PSScriptRoot\ParseId.ps1 -Id $id -Silent -Force:$Force
}