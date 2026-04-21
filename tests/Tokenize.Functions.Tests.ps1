BeforeAll {
    # tests\Get-Emoji.Tests.ps1 -> src\Get-Emoji.ps1
    . $PSCommandPath.Replace('.Tests.ps1','.ps1').Replace('tests', 'src')
    # . $PSScriptRoot\..\src\Tokenize.ps1
}

Describe Split-Cebuano-Words {
    It "should parse cebuano word" {
        $textToken = @{
            "Type" = "TEXT"
            "Content" = "<b lang=""ceb"">a</b><i>n</i> letter A. <b lang=""ceb"">walay —</b> illiterate."
        }
        $tokens = Split-Cebuano-Words -Token $textToken
        $tokens | Should -HaveCount 4
        $tokens[0].Type | Should -Be "CEBWORD"
        $tokens[0].Content | Should -Be "a"
    }
}
