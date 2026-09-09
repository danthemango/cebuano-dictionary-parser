BeforeAll {
}

Describe "Tokenize" {
    # load functions
    . "$PSScriptRoot\Tokenize.Functions.ps1"

    $ExpectedFiles = Get-ChildItem "$PSScriptRoot\expected\tokens_*.csv" |
        ForEach-Object {
            $suffix = $_.BaseName -replace '^tokens_', ''

            @{
                ExpectedFile = $_.FullName
                InputFile    = Join-Path $PSScriptRoot "..\step2_split_paras\data\para_$suffix.xml"
                Name         = $_.Name
            }
        }

    It "Should tokenize <Name> correctly" -TestCases $ExpectedFiles {
        param(
            $ExpectedFile,
            $InputFile
        )

        Test-Path $InputFile | Should -BeTrue -Because "Expecting file $InputFile"

        # Run tokenizer
        $actual = & "$PSScriptRoot\TokenizeFile.ps1" -InFile $InputFile

        # Load expected output
        $expected = Import-Csv $ExpectedFile

        # Normalize for comparison
        $actualCsv = $actual | ConvertTo-Csv -NoTypeInformation
        $expectedCsv = $expected | ConvertTo-Csv -NoTypeInformation

        $actualCsv | Should -BeExactly $expectedCsv
    }
}