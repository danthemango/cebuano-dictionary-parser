<#
.PARAMETER Force
Overwrite the output file
#>
param (
    # if true, update the files even if they exist
    [switch]$Force
)

[string]$inDir = "$PSScriptRoot\..\step3_tokenize\data"
Get-ChildItem -Path $inDir -Filter "tokens_*.csv" | ForEach-Object -Parallel {
    $inFile = $_
    # get the Id number from a file with pattern "tokens_[a-z]_[0-9]+.csv"
    $id = [regex]::Match($inFile.Name, 'tokens_[a-z]_(\d+)\.csv').Groups[1].Value
    step4_parse\ParseId.ps1 -Id $id -Silent -Force:$using:Force
}