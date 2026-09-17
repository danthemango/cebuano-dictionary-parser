<#
.DESCRIPTION
run tokenization on all definitions
.PARAMETER Force
Overwrite the output file
.PARAMETER Verbose
Print full error message
#>
param (
    # if true, update the files even if they exists
    [switch]$Force,
    [switch]$Verbose
)

[string]$inDir = "step2_split_paras\data"
[string]$outDir = "step3_tokenize\data"
[string]$errorDir = "step3_tokenize\errors"
mkdir -Force $outDir | Out-Null
mkdir -Force $errorDir | Out-Null

Get-ChildItem -Path $inDir -Filter "para_*.xml" | ForEach-Object -Parallel {
    [int]$id = [regex]::Match($_.Name, 'para_._(\d+)\.xml').Groups[1].Value
    [string]$outDir = "step3_tokenize\data"
    $inFile = $_
    [string]$outFile = $inFile.FullName -replace "para_", "tokens_"
    $outFile = $outFile -replace ".xml$", ".csv"
    $outFile = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $outFile)

    [string]$errorDir = "step3_tokenize\errors"
    [string]$errorFile = $inFile.FullName -replace "para_", "error_"
    $errorFile = $errorFile -replace ".xml$", ".txt"
    $errorFile = Join-Path -Path $errorDir -ChildPath (Split-Path -Leaf $errorFile)
    if (Test-Path $errorFile) {
        Remove-Item -Path $errorFile -Force
    }

    if ((-Not (Test-Path $outFile)) -Or $using:Force) {
        try {
            step3_tokenize\TokenizeFile.ps1 -InFile $inFile | Export-Csv -Path $outFile -NoTypeInformation
        } catch {
            # delete the outFile if partially created
            if (Test-Path $outFile) {
                Remove-Item $outFile
            }

            $errorMessage = "Failed to tokenize $inFile`n$_"
            $errorMessage += "`nStack Trace:`n$($_.ScriptStackTrace)"
            [xml]$inFileXml = Get-Content $inFile
            $errorMessage += "`n`n$($inFileXml.root.InnerXml)"
            $errorMessage | Out-File -FilePath $errorFile -Encoding UTF8
            if ($using:Verbose) {
                Write-Error $errorMessage
            } else {
                $err = $_
                Write-Error "Failed to tokenize $id : $err"
            }
        }
    }
}