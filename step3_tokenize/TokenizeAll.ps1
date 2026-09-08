. $PSScriptRoot\Tokenize.Functions.ps1

[string]$inDir = "step2_split_paras\data"
[string]$outDir = "step3_tokenize\data"
mkdir -Force $outDir

foreach ($inFile in Get-ChildItem -Path $inDir -Filter "para_*.xml") {
    $outFile = $inFile.FullName -replace "para_", "tokens_"
    $outFile = $outFile -replace ".xml$", ".csv"
    $outFile = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFile)

    . $PSScriptRoot\TokenizeFile.ps1 -InFile $inFile | Export-Csv -Path $outFile -NoTypeInformation
}