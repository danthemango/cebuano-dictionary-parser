<#
.PARAMETER Force
Overwrite the output file
#>
param (
    # if true, update the files even if they exist
    [switch]$Force
)

[string]$inDir = "$PSScriptRoot\..\step3_tokenize\data"
$inFiles = Get-ChildItem -Path $inDir -Filter "tokens_*.csv"

# skip files that already exist unless Force is set
if (-Not $Force) {
    $inFiles = $inFiles | Where-Object {
        [string]$outDir = "$PSScriptRoot\data"
        $outFile = $_.Name -replace "tokens_", "parse_" -replace "\.csv$", ".json"
        [string]$outFilepath = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFile)
        -Not (Test-Path $outFilepath)
    }
}

$ids = $inFiles | ForEach-Object {
    [regex]::Match($_.Name, 'tokens_[a-z]_(\d+)\.csv').Groups[1].Value
}

$ids | ForEach-Object -Parallel {
    step4_parse\ParseId.ps1 -Id $_ -Silent -Force:$using:Force
}
