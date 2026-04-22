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

Describe Split-Links {
    # It "Should split links" {
    #     $textToken = Get-TextToken -Text 'see <span class="sc" lang="ceb"><a href="#abir">abir</a></span> and <span class="sc" lang="ceb"><a href="#abir">abir</a></span>.'
    #     $tokens = Split-Links -Token $textToken
    #     $tokens | Should -HaveCount 2
    #     $tokens[0].Type | Should -Be "TEXT"
    #     $tokens[1].Type | Should -Be "LINK"
    #     $tokens[1].Content | Should -Be "abir"
    # }

    It "Should split links with other tokens" {
        $textToken = Get-TextToken -Text '<b lang="ceb">-a</b> subjunctive direct passive affix. <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#x-un">-un</a></span>.'
        $tokens = Split-Links -Token $textToken
        $tokens | Should -HaveCount 2
        $tokens[0].Type | Should -Be "TEXT"
        $tokens[1].Type | Should -Be "LINK"
        $tokens[1].Content | Should -Be "-un"
    }

    It "Should split links with other tokens" {
        $content = '<b lang="ceb">abi</b> = <span class="sc" lang="ceb"><a href="#abir">abir</a></span><b lang="ceb">1, 2</b>.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens | Should -HaveCount 2
        $tokens[0].type | Should -Be "TEXT"
        $tokens[1].type | Should -Be "LINK"
        $tokens[1].Content | Should -Be "abir1, 2"
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
