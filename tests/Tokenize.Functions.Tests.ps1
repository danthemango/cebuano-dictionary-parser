BeforeAll {
    # tests\Get-Emoji.Tests.ps1 -> src\Get-Emoji.ps1
    . $PSCommandPath.Replace('.Tests.ps1','.ps1').Replace('tests', 'src')

    function Get-TextToken {
        param (
            [string]$Text
        )
        [PSCustomObject]@{
            Type = "TEXT"
            Content = $Text
        }
    }
}

Describe Split-Cebuano-Words {
    It "should parse cebuano word" {
        $textToken = Get-TextToken -Text '<b lang="ceb">a</b><i>n</i> letter A. <b lang="ceb">walay —</b> illiterate.'
        $tokens = Split-Cebuano-Words -Token $textToken
        $tokens | Should -HaveCount 4
        $tokens[0].Type | Should -Be "CEBWORD"
        $tokens[0].Content | Should -Be "a"
    }
}

# Describe Split-Nums {
#     It "shoulde parse number lists" {
#         $textToken = Get-TextToken -Text '<b lang="ceb">abi</b> = <span class="sc" lang="ceb"><a href="#abir">abir</a></span><b lang="ceb">1, 2</b>.'
#         $tokens = Split-Nums -Token $textToken
#         $tokens | Should -HaveCount 3
#         $tokens[2].Type | Should -Be "NUMBER"
#         $tokens[2].Content | Should -Be "1, 2"
#     }
# }
