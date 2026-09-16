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

Repair-Typos -Id 10986 -SearchPattern '<span class="sc" lang="ceb">ibm</span>' -Replacement 'IBM'
Repair-Typos -Id 3565 -SearchPattern '<i>a</i> protrusion' -Replacement 'a protrusion'
Repair-Typos -Id 6600 -SearchPattern '<b>1</b> a' -Replacement '<b>1a</b>'
Repair-Typos -Id 6742 -SearchPattern '<i lang="ceb">Ihúlug ning suláta, Mail this letter.</i>' -Replacement '<i lang="ceb">Ihúlug ning suláta,</i> Mail this letter.'
Repair-Typos -Id 6885 -SearchPattern '<i lang="ceb">Hustu na rung ilarga, Now is a good time to leave.</i>' -Replacement '<i lang="ceb">Hustu na rung ilarga,</i> Now is a good time to leave.'
Repair-Typos -Id 6158 -SearchPattern '<i lang="ceb">Pakigpúlung nga hinashásan, Highly polished speech.</i>' -Replacement '<i lang="ceb">Pakigpúlung nga hinashásan,</i> Highly polished speech.'
Repair-Typos -Id 10423 -SearchPattern '<i lang="ceb">Labung ug sinultihan, Boastful in his speech.</i>' -Replacement '<i lang="ceb">Labung ug sinultihan,</i> Boastful in his speech.'
Repair-Typos -Id 11368 -SearchPattern '<i lang="ceb">Wà malínis ang ákung kináun, What I ate did not dissolve.</i>' -Replacement '<i lang="ceb">Wà malínis ang ákung kináun,</i> What I ate did not dissolve.'
# I'll just strip out all tags of this section since it's just a long explanation
Repair-Typos -Id 11956 -SearchPattern '(<i lang="ceb">Past</i>: <b lang="ceb">nag-</b><i lang="ceb">or</i><b lang="ceb">ga-</b>. <i lang="ceb">Subjunctive</i>: <b lang="ceb">mag-</b>.)' -Replacement '(Past: nag- or ga-. Subjunctive: mag-.)'
# remove thsi explanation section since it's not labelled as part of any def
Repair-Typos -Id 11956 -SearchPattern 'Verbs with <i lang="ceb">mag-</i>, <i lang="ceb">nag-</i> have the following meanings \(as opposed to verbs with <i lang="ceb">mi-</i>, <i lang="ceb">mu-</i> — <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#mu-">mu-</a></span>\):', ''