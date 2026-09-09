param (
    # if true, update the files even if they exist
    [switch]$Force
)

[string]$inDir = "step3_tokenize\data"
[string]$outDir = "step4_parse\data"
mkdir -Force $outDir | Out-Null

$errorDir = "step4_parse\errors"
mkdir -Force $errorDir | Out-Null

Get-ChildItem -Path $inDir -Filter "tokens_*.csv" | ForEach-Object {
    $inFile = $_

    $outFile = $inFile.FullName -replace "tokens_", "parse_"
    $outFile = $outFile -replace "\.csv$", ".json"
    $outFile = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFile)

    # delete the error file if it exists
    $errorFile = $inFile.FullName -replace "tokens_", "error_"
    $errorFile = $errorFile -replace "\.csv$", ".txt"
    $errorFile = Join-Path -Path $errorDir -ChildPath (Split-Path -Leaf $errorFile)

    if ((-not (Test-Path $outFile)) -or $Force) {
        try {
            if (Test-Path $errorFile) {
                Remove-Item -Path $errorFile -Force
            }

            . $PSScriptRoot\ParseFile.ps1 -InFile $inFile |
                ConvertTo-Json -Depth 100 |
                Set-Content -Path $outFile -Encoding UTF8
        }
        catch {
            # delete the outFile if partially created
            if (Test-Path $outFile) {
                Remove-Item $outFile
            }

            $errorMessage = "Failed to parse $inFile`n$_"
            $errorMessage += "`nStack Trace:`n$($_.ScriptStackTrace)"

            # Include input file contents for debugging
            $errorMessage += "`n`nInput File:`n"
            $errorMessage += Get-Content $inFile -Raw

            $errorMessage | Out-File -FilePath $errorFile -Encoding UTF8

            Write-Error $errorMessage
        }
    }
}