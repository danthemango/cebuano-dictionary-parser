# fix some typos
function Repair-Typos {
    param (
        [string]$FilePath,
        [string]$SearchPattern,
        [string]$Replacement
    )

    Write-Output "Fixing typos in file: $FilePath"

    # Read the content of the file
    $fileContent = Get-Content $FilePath

    # Replace the search pattern with the replacement text
    $fileContent = $fileContent -replace $SearchPattern, $Replacement

    # Write the modified content back to the file
    $fileContent | Set-Content $FilePath

    Write-Output "Typos fixed in file: $FilePath"
}

Repair-Typos -FilePath "$PSScriptRoot\data\para_b_3565.xml" -SearchPattern '<i>a</i> protrusion' -Replacement 'a protrusion'