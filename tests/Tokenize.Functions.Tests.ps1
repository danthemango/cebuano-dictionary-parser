BeforeAll {
    # tests\Get-Emoji.Tests.ps1 -> src\Get-Emoji.ps1
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('tests', 'src')

    function Get-TextToken {
        param (
            [string]$Text
        )
        [PSCustomObject]@{
            Type    = "TEXT"
            Content = $Text
        }
    }
}

Describe Split-CebuanoWords {
    It "should tokenize cebuano word" {
        $textToken = Get-TextToken -Text '<b lang="ceb">a</b><i>n</i> letter A. <b lang="ceb">walay —</b> illiterate.'
        $tokens = Split-CebuanoWords -Token $textToken
        $tokens | Should -HaveCount 4
        $tokens[0].Type | Should -Be "CEBWORD"
        $tokens[0].Content | Should -Be "a"
    }
}

Describe Split-CebuanoPhrases {
    It "should tokenize cebuano phrase" {
        $content = '<i lang="ceb">Lagmit hiligsan ang bátà kay nag-abay sa tartanilya,</i>'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-CebuanoPhrases -Token $textToken
        $tokens[0].Type | Should -Be "CEBPHRASE"
        $tokens[0].Content | Should -Be "Lagmit hiligsan ang bátà kay nag-abay sa tartanilya"
    }

    It "Should not tokenize cebuano phrase that has no comma" {
        $content = 'have a snake born at the same time one is born. The snake is called one’’s twin (<i lang="ceb">kalúha</i>) and is supposed to bring him and his family luck'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-CebuanoPhrases -Token $textToken
        $tokens[0].Type | Should -Be "TEXT"
        # $tokens[0].Content | Should -Be ""
    }

    It "Should not capture parts of the text that are not in the same phrase" {
        $content = '(from <i lang="ceb">sábà dihà untuy</i>) shut up! <i lang="ceb">ábà tuy, maáyu ka lang sa tayáda, wà kay tadtad,</i> Shut up! You’’re great at talking, but let’’s see you do s.t.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-CebuanoPhrases -Token $textToken
        $tokens | Should -HaveCount 3
        $tokens[1].Content | Should -Be "ábà tuy, maáyu ka lang sa tayáda, wà kay tadtad"
        $tokens[0].Type | Should -Be "TEXT"
    }
}

Describe Split-Links {
    It "Should split links for abir" {
        $textToken = Get-TextToken -Text '<b lang="ceb">-a</b> subjunctive direct passive affix. <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#x-un">-un</a></span>.'
        $tokens = Split-Links -Token $textToken
        $tokens | Should -HaveCount 2
        $tokens[0].Type | Should -Be "TEXT"
        $tokens[1].Type | Should -Be "LINK"
        $tokens[1].Content | Should -Be "-un"
    }

    It "Should split links with numbers" {
        $content = '<b lang="ceb">abi</b> = <span class="sc" lang="ceb"><a href="#abir">abir</a></span><b lang="ceb">1, 2</b>.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens | Should -HaveCount 2
        $tokens[0].type | Should -Be "TEXT"
        $tokens[1].type | Should -Be "LINK"
        $tokens[1].Content | Should -Be "abir: 1, 2"
    }

    It "Should tokenize links with wordtype v" {
        $content = '= <span class="sc" lang="ceb"><a href="#abaxga">abága</a></span>, <i lang="ceb">v</i>.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens[0].Type | Should -Be "LINK"
        $tokens[0].Content | Should -Be 'abága: v'
    }

    It "Should tokenize links with wordtype n and number 4" {
        $content = '<i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>, <i lang="ceb">n</i><b lang="ceb">4</b>.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens[0].Content | Should -Be "abay: n 4"
    }

    It "Should tokenize links with wordtype n and number 4 in brackets" {
        $content = '(<i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>, <i lang="ceb">n</i><b lang="ceb">4</b>).'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens[0].Content | Should -Be "abay: n 4"
        $tokens[0].Type | Should -Be "LINK"
    }

    It "Should tokenize links without href" {
        $content = '= <span class="sc" lang="ceb">tangdayan</span>.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens[0].Content | Should -Be 'tangdayan'
        $tokens[0].Type | Should -Be "LINK"
    }

    It "Should tokenize a link with wordtype v number 1 and a dot inside of the tag" {
        $content = '= <span class="sc" lang="ceb"><a href="#tangdiq">tangdì</a></span>, <i lang="ceb">v1.</i>'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens[0].Content | Should -Be 'tangdì: v1'
        $tokens[0].Type | Should -Be "LINK"
    }

    It "Should tokenize links with dangling number at end" {
        $content = '= <span class="sc" lang="ceb"><a href="#abud">abud</a></span>, <i lang="ceb">n</i> 2.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-Links -Token $textToken
        $tokens[0].Content | Should -Be 'abud: n 2'
        $tokens[0].Type | Should -Be "LINK"
    }
}

Describe Tokenize {
    It "Should do basic parsing" {
        $textToken = Get-TextToken -Text '<b lang="ceb">a</b><i>n</i> letter A. <b lang="ceb">walay —</b> illiterate.'
        $tokens = Tokenize -Token $textToken
        $tokenlist = '[{"Type":"CEBWORD","Content":"a"},{"Type":"WORDTYPE","Content":"n"},{"Type":"TEXT","Content":"letter A."},{"Type":"CEBWORD","Content":"walay —"},{"Type":"TEXT","Content":"illiterate."}]'
        $tokens | ConvertTo-Json -Compress | Should -Be $tokenlist
    }

    It "Should tokenize links with numbers" {
        $textToken = Get-TextToken -Text '<b lang="ceb">abi</b> = <span class="sc" lang="ceb"><a href="#abir">abir</a></span><b lang="ceb">1, 2</b>.'
        $tokens = Tokenize -Token $textToken
        $tokenlist = '[{"Type":"CEBWORD","Content":"abi"},{"Type":"LINK","Content":"abir: 1, 2"}]'
        $tokens | ConvertTo-Json -Compress | Should -Be $tokenlist
    }

    It "Should tokenize links with wordtype v" {
        $textToken = Get-TextToken -Text '= <span class="sc" lang="ceb"><a href="#abaxga">abága</a></span>, <i lang="ceb">v</i>.'
        $tokens = Tokenize -Token $textToken
        $tokens | ConvertTo-Json -Compress | Should -Be '{"Type":"LINK","Content":"abága: v"}'
    }
}
