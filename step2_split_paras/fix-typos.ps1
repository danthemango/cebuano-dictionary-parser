# fix some typos
function Repair-Typos {
    param (
        [int]$Id,
        [string]$SearchPattern,
        [string]$Replacement
    )

    [string]$filePath = "$PSScriptRoot\data\para_*_$Id.xml"

    Write-Output "Fixing typos in file: $FilePath"

    # Read the content of the file
    $fileContent = Get-Content $FilePath

    # Replace the search pattern with the replacement text
    $fileContent = $fileContent -replace $SearchPattern, $Replacement

    # Write the modified content back to the file
    $fileContent | Set-Content $FilePath

    Write-Output "Typos fixed in file: $FilePath"
}

Repair-Typos -Id 3565 -SearchPattern '<i>a</i> protrusion' -Replacement 'a protrusion'
Repair-Typos -Id 6047 -SearchPattern '<i lang="ceb">1</i>' -Replacement '<b>1</b>'
