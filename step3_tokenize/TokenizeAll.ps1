param (
    # if true, update the files even if they exists
    [switch]$Force
)

[string]$inDir = "step2_split_paras\data"
[string]$outDir = "step3_tokenize\data"
mkdir -Force $outDir | Out-Null
$errorDir = "step3_tokenize\errors"
mkdir -Force $errorDir | Out-Null

foreach ($inFile in Get-ChildItem -Path $inDir -Filter "para_*.xml") {
    $outFile = $inFile.FullName -replace "para_", "tokens_"
    $outFile = $outFile -replace ".xml$", ".csv"
    $outFile = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFile)

    # delete the error file if it exists
    $errorFile = $inFile.FullName -replace "para_", "error_"
    $errorFile = $errorFile -replace ".xml$", ".txt"
    $errorFile = Join-Path -Path $errorDir -ChildPath (Split-Path -Leaf $errorFile)

    if (-Not (Test-Path $outFile)) {
        try {
            if (Test-Path $errorFile) {
                Remove-Item -Path $errorFile -Force
            }
            . $PSScriptRoot\TokenizeFile.ps1 -InFile $inFile | Export-Csv -Path $outFile -NoTypeInformation
        } catch {
            $errorMessage = "Failed to tokenize $inFile $_"
            $errorMessage += "`nStack Trace:`n$($_.ScriptStackTrace)"
            $errorMessage | Out-File -FilePath $errorFile -Encoding UTF8
            Write-Error $errorMessage
        }
    }
}