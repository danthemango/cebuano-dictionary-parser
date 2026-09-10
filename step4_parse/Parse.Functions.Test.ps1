BeforeAll {
}

Describe "Parse" {
    # load functions
    . "$PSScriptRoot\Parse.Functions.ps1"

    $ExpectedFiles = Get-ChildItem "$PSScriptRoot\expected\parse_*.json" |
        ForEach-Object {
            $suffix = $_.BaseName -replace '^parse_', ''

            @{
                ExpectedFile = $_.FullName
                InputFile    = Join-Path $PSScriptRoot "..\step3_tokenize\data\tokens_$suffix.csv"
                Name         = $_.Name
            }
        }

    It "Should parse <Name> correctly" -TestCases $ExpectedFiles {
        param(
            $ExpectedFile,
            $InputFile
        )

        Test-Path $InputFile | Should -BeTrue -Because "Expecting file $InputFile"

        # Run tokenizer
        $actual = & "$PSScriptRoot\ParseFile.ps1" -InFile $InputFile
        $expected = Get-Content $ExpectedFile -Raw | ConvertFrom-Json

        $actualJson = $actual | ConvertTo-Json -Depth 100
        $expectedJson = $expected | ConvertTo-Json -Depth 100

        $actualJson | Should -BeExactly $expectedJson
    }
}