<#
.DESCRIPTION
Copy the known definition files for testing after updates.
#>

$ids = @(
    0,
    10583,
    108,
    1121,
    1197,
    1235,
    13092,
    13875,
    15,
    150,
    1535,
    1632,
    1697,
    1789,
    1776,
    20434,
    2073,
    219,
    25,
    2995,
    42,
    4310,
    4595,
    485,
    686,
    89,
    9492
)

foreach ($id in $ids) {
    . $PSScriptRoot\RunId.ps1 -Id $id -CopyToExpected -SkipTypos
}