param (
    [switch]$Verbose
)

# fix some typos
function Repair-Typos {
    param (
        [int]$Id,
        [string]$SearchPattern,
        [string]$Replacement
    )

    [string]$filePath = "$PSScriptRoot\data\para_*_$Id.xml"

    # Read the content of the file
    $fileContent = Get-Content $FilePath

    # Replace the search pattern with the replacement text
    $fileContent = $fileContent -replace $SearchPattern, $Replacement

    # Write the modified content back to the file
    $fileContent | Set-Content $FilePath

    if ($Verbose) {
        Write-Output "Typos fixed in file: $FilePath"
    }
}

Write-Output "fix typos"

Repair-Typos -Id 3565 -SearchPattern '<i>a</i> protrusion' -Replacement 'a protrusion'
Repair-Typos -Id 6600 -SearchPattern '<b>1</b> a' -Replacement '<b>1a</b>'
Repair-Typos -Id 6742 -SearchPattern '<i lang="ceb">Ihúlug ning suláta, Mail this letter.</i>' -Replacement '<i lang="ceb">Ihúlug ning suláta,</i> Mail this letter.'
Repair-Typos -Id 6885 -SearchPattern '<i lang="ceb">Hustu na rung ilarga, Now is a good time to leave.</i>' -Replacement '<i lang="ceb">Hustu na rung ilarga,</i> Now is a good time to leave.'
