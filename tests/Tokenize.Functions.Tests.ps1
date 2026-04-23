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
        # TODO update this to remove the comma at the end later
        $tokens[0].Content | Should -Be "Lagmit hiligsan ang bátà kay nag-abay sa tartanilya,"

        $content = '<b lang="ceb">*abáhu</b><b lang="ceb">— kunsidirasiyun, dispusisiyun</b><i>n</i> bound by s.o.’’s will. <i lang="ceb">Abáhu (báhu) <span class="corr" id="xd20e4931" title="Source: kunsididirasiyun">kunsidirasiyun</span> ku sa ákung bána,</i> I am bound by my husband’’s decisions.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-CebuanoPhrases -Token $textToken
        $tokens[1].Type | Should -Be "CEBPHRASE"
        $tokens[1].Content | Should -Be 'Abáhu (báhu) <span class="corr" id="xd20e4931" title="Source: kunsididirasiyun">kunsidirasiyun</span> ku sa ákung bána,'
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
        $tokens = Update-ChangeCebWord -Token $textToken
        $tokens = Split-CebuanoPhrases -Token $textToken
        $tokens | Should -HaveCount 3
        # TODO update this to remove the comma at the end later
        $tokens[1].Content | Should -Be "ábà tuy, maáyu ka lang sa tayáda, wà kay tadtad,"
        $tokens[1].Type | Should -Be "CEBPHRASE"
    }

    It "Should parse the cebuano phrase and english phrase" {
        $content = 'affix added to nouns forming words which refer to a specific one of several: <i lang="ceb">Kanang isdáa, dílì kadtu,</i> That fish there, not that one further over.'
        $textToken = Get-TextToken -Text $content
        $tokens = Split-CebuanoPhrases -Token $textToken
        $tokens[1].Content | Should -Be "Kanang isdáa, dílì kadtu,"
        $tokens[1].Type | Should -Be "CEBPHRASE"
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

Describe Update-ChangeCebWord {
    It "Should update the cebword content to be the same as the word" {
        $content = '(from <i lang="ceb">sábà dihà untuy</i>) shut up! <i lang="ceb">ábà tuy, maáyu ka lang sa tayáda, wà kay tadtad,</i> Shut up! You’’re great at talking, but let’’s see you do s.t.'
        $textToken = Get-TextToken -Text $content
        $updatedToken = Update-ChangeCebWord -Token $textToken
        $updatedToken.Content | Should -Be '(from <i lang="cebword">sábà dihà untuy</i>) shut up! <i lang="ceb">ábà tuy, maáyu ka lang sa tayáda, wà kay tadtad,</i> Shut up! You’’re great at talking, but let’’s see you do s.t.'
    }

    It "Should not update a non-cebword content" {
        $content = 'affix added to nouns forming words which refer to a specific one of several: <i lang="ceb">Kanang isdáa, dílì kadtu,</i> That fish there, not that one further over.'
        $token = Get-TextToken -Text $content
        $token = Update-ChangeCebWord -Token $token
        $token.Content | Should -Be 'affix added to nouns forming words which refer to a specific one of several: <i lang="ceb">Kanang isdáa, dílì kadtu,</i> That fish there, not that one further over.'
    }

    It "Should not update a cebword in the proper format of a cebphrase" {
        # from word "-a(←)"
        $content = '<i lang="ceb">Dakúa uy!</i> My! How big it is!'
        $token = Get-TextToken -Text $content
        $token = Update-ChangeCebWord -Token $token
        $token.Content | Should -Be '<i lang="ceb">Dakúa uy!</i> My! How big it is!'

        $content = '<i lang="ceb">Patyun tikaw, irúa ka!</i> I’’ll kill you, you dog you!'
        $token = Get-TextToken -Text $content
        $token = Update-ChangeCebWord -Token $token
        $token.Content | Should -Be '<i lang="ceb">Patyun tikaw, irúa ka!</i> I’’ll kill you, you dog you!'

        $content = '<i lang="ceb">Ngilngígang awtúha à!</i> That’’s some car!'
        $token = Get-TextToken -Text $content
        $token = Update-ChangeCebWord -Token $token
        $token.Content | Should -Be '<i lang="ceb">Ngilngígang awtúha à!</i> That’’s some car!'


        # TODO
        # $content = 'nimble, quick in reaction. <i lang="ceb">Ang musáyaw sa tinikling kinahanglang abtik ug tiil,</i> Whoever dances the <i lang="ceb">tinikling</i> has to have nimble feet.'
        # $token = Get-TextToken -Text $content
        # $token = Update-ChangeCebWord -Token $token
        # $token.Content | Should -Be 'hello world'
    }

    It "Should recognize a pattern that has a dot but no spaces" {
        $content = 'be infested with <i lang="ceb">abungaw.</i>'
        $token = Get-TextToken -Text $content
        $token = Update-ChangeCebWord -Token $token
        $token.Content | Should -Be 'be infested with <i lang="cebword">abungaw.</i>'
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

    It "Should tokenize cebword and cebphrase correctly" {
        $content = 'nimble, quick in reaction. <i lang="ceb">Ang musáyaw sa tinikling kinahanglang abtik ug tiil,</i> Whoever dances the <i lang="ceb">tinikling</i> has to have nimble feet.'
        $textToken = Get-TextToken -Text $content
        $tokens = Tokenize -Token $textToken
        $tokens | ConvertTo-Json -Compress | Should -Be '[{"Type":"TEXT","Content":"nimble, quick in reaction."},{"Type":"CEBPHRASE","Content":"Ang musáyaw sa tinikling kinahanglang abtik ug tiil,"},{"Type":"TEXT","Content":"Whoever dances the <i lang=\"cebword\">tinikling</i> has to have nimble feet."}]'
    }
    
    # It "Should tokenize the -a(←) definition" {
    #     $content = '<b lang="ceb">-a(←)</b><b>1</b> affix added to nouns forming words which refer to a specific one of several: <i lang="ceb">Kanang isdáa, dílì kadtu,</i> That fish there, not that one further over. <i lang="ceb">Háing baláya ang íla?</i> Which house is theirs? <b>1a</b> added to possessive pronouns: the particular one that belongs to [so-and-so]. <i lang="ceb">Dakù ang amúang balay, gamay tung iláha,</i> Our house is large, and theirs is small. <b>2</b> affix added to adjectives to form exclamation. <i lang="ceb">Dakúa uy!</i> My! How big it is! <i lang="ceb">Patyun tikaw, irúa ka!</i> I’’ll kill you, you dog you! <i lang="ceb">Ngilngígang awtúha à!</i> That’’s some car!'
    #     $textToken = Get-TextToken -Text $content
    #     $tokens = Tokenize -Token $textToken
    #     $tokens | ConvertTo-Json -Compress | Should -Be 'Hello world'
    # }
}
