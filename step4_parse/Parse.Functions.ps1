function Get-Token {
    param([object[]]$Tokens, [int]$i)
    if ($i -ge 0 -and $i -lt $Tokens.Count) { $Tokens[$i] } else { $null }
}

<#
.DESCRIPTION
    returns true if the token has a given type
#>
function IsType {
    param($tok, [string]$type)
    $tok -and ($tok.Type -eq $type)
}

<#
.DESCRIPTION
    parse definition
#>
function Set-Def {
    <#
      DEF ::= (TEXT | LINK)+
      Returns {Found, NextIndex, Def:{Text, Links[], Word}, Diagnostics}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $tok = Get-Token $Tokens $i
    if (-Not $tok) {
        return [PSCustomObject]@{ Found=$false; NextIndex=$i; Def=$null; Diagnostics=@(
            [PSCustomObject]@{ Index=$i; Message='DEF: no token'; Token=$null }
        ) }
    }

    # Case 1: (TEXT | LINK)+
    $text_link_arr = @()
    while ((IsType $tok 'TEXT') -or (IsType $tok 'LINK'))
    {
        $text_link_arr += [PSCustomObject]@{
            Type = $tok.Type
            Content = $tok.Content
        }

        $i++
        $tok = Get-Token $Tokens $i

        # end of input
        if (-Not $tok) {
            break
        }
    }

    # # Case 3: CEBWORD
    # if (IsType $tok 'CEBWORD') {
    #     $word = $tok.Content; $i++
    #     return [PSCustomObject]@{
    #         Found   = $true
    #         NextIndex = $i
    #         Def       = [PSCustomObject]@{ Text=$null; Links=@(); Word=$word }
    #         Diagnostics = $diag
    #     }
    # }

    if ($text_link_arr.Count -eq 0) {
        [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            Def         = $null
            Diagnostics = $diag + [PSCustomObject]@{ Index=$i; Message="DEF: unexpected $($tok.Type)"; Token=$tok }
        }
    } elseif ($text_link_arr.Count -eq 1) {
        [PSCustomObject]@{
            Found     = $true
            NextIndex   = $i
            Def         = $text_link_arr[0]
            Diagnostics = $diag
        }
    } else {
        [PSCustomObject]@{
            Found     = $true
            NextIndex   = $i
            Def         = $text_link_arr
            Diagnostics = $diag
        }
    }
}

function Set-Example {
    <#
      EX ::= CEBPHRASE TEXT
      Returns {Found, NextIndex, Example:{Phrase, Gloss}, Diagnostics}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $phraseTok = Get-Token $Tokens $i
    if (-Not $phraseTok -or -Not ($phraseTok.Type -eq 'CEBPHRASE')) {
        return [PSCustomObject]@{ Found=$false; NextIndex=$i; Example=$null; Diagnostics=$diag }
    }
    $i++

    $glossTok = Get-Token $Tokens $i
    if (-Not (IsType $glossTok 'TEXT')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $StartIndex     # roll back
            Example     = $null
            Diagnostics = $diag + [PSCustomObject]@{
                Index=$i; Message='EX: expected TEXT after phrase'; Token=$glossTok
            }
        }
    }
    $i++

    [PSCustomObject]@{
        Found   = $true
        NextIndex = $i
        Example   = [PSCustomObject]@{
            Phrase = $phraseTok.Content
            Gloss  = $glossTok.Content
        }
        Diagnostics = $diag
    }
}

function Set-Examples {
    <#
      Parse zero or more EX pairs.
      Returns {Examples[], NextIndex}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex
    $examples = @()
    while ($true) {
        $ex = Set-Example -Tokens $Tokens -StartIndex $i
        if (-Not $ex.Found) { break }
        $examples += $ex.Example
        $i = $ex.NextIndex
    }
    [PSCustomObject]@{ Examples=$examples; NextIndex=$i }
}

function Search-DefEx {
    <#
      DEFEX ::= DEF EX*
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $def = Set-Def -Tokens $Tokens -StartIndex $i
    if (-Not $def.Found) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $def.NextIndex
            DefEx       = $null
            Diagnostics = $def.Diagnostics
        }
    }
    $i = $def.NextIndex

    $exs = Set-Examples -Tokens $Tokens -StartIndex $i
    $i = $exs.NextIndex

    [PSCustomObject]@{
        Found   = $true
        NextIndex = $i
        DefEx     = [PSCustomObject]@{ Def=$def.Def; Examples=$exs.Examples }
        Diagnostics = $diag
    }
}

function Set-NumDef {
    <#
      NUMDEF ::= NUMBER [CEBWORD] [CLASS] DEFEX
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $numTok = Get-Token $Tokens $i
    if (-Not (IsType $numTok 'NUMBER')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            NumDef      = $null
            Diagnostics = $diag + [PSCustomObject]@{ Index=$i; Message='NUMDEF: expected NUMBER'; Token=$numTok }
        }
    }
    $i++

    # collect CEBWORD conjugation
    $conjugation = $null
    if (IsType (Get-Token $Tokens $i) 'CEBWORD') {
        $conjugation += (Get-Token $Tokens $i).Content
        $i++
    }

    # collect CLASS
    $class = $null
    if (IsType (Get-Token $Tokens $i) 'CLASS') {
        $class += (Get-Token $Tokens $i).Content
        $i++
    }

    $defex = Search-DefEx -Tokens $Tokens -StartIndex $i
    if (-Not $defex.Found) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $defex.NextIndex
            NumDef      = $null
            Diagnostics = $diag + $defex.Diagnostics
        }
    }
    $i = $defex.NextIndex


    $numDef = [PSCustomObject]@{
        Number = $numTok.Content
        DefEx  = $defex.DefEx
    }

    if ($null -ne $class) {
        $numDef | Add-Member -MemberType NoteProperty -Name "Class" -Value $class
    }

    if ($null -ne $conjugation) {
        $numDef | Add-Member -MemberType NoteProperty -Name "Conjugation" -Value $conjugation
    }

    [PSCustomObject]@{
        Found   = $true
        NextIndex = $i
        NumDef    = $numDef
        Diagnostics = $diag
    }
}

function Set-WtDef {
    <#
      WTDEF ::= WORDTYPE CLASS* ( NUMDEF+ | DEFEX )
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    # Require WORDTYPE
    $wtTok = Get-Token $Tokens $i
    if (-Not (IsType $wtTok 'WORDTYPE')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            WtDef       = $null
            Diagnostics = $diag + [PSCustomObject]@{
                Index = $i; Message = 'WTDEF: expected WORDTYPE'; Token = $wtTok
            }
        }
    }
    $i++

    # collect CLASS*
    $classes = @()
    while (IsType (Get-Token $Tokens $i) 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
        $i++
    }

    # Branch A: NUMDEF+ (NUMBER DEFEX), after optional classes
    if (IsType (Get-Token $Tokens $i) 'NUMBER') {
        $numdefs = @()
        while (IsType (Get-Token $Tokens $i) 'NUMBER') {
            $nd = Set-NumDef -Tokens $Tokens -StartIndex $i
            if (-Not $nd.Found) {
                return [PSCustomObject]@{
                    Found     = $false
                    NextIndex   = $nd.NextIndex
                    WtDef       = $null
                    Diagnostics = $diag + $nd.Diagnostics
                }
            }
            $numdefs += $nd.NumDef
            $i = $nd.NextIndex
        }

        $node = [PSCustomObject]@{
            WordType     = $wtTok.Content
            Classes      = $classes
            NumberedDefs = $numdefs
        }

        return [PSCustomObject]@{
            Found     = $true
            NextIndex   = $i
            WtDef       = $node
            Diagnostics = $diag
        }
    }

    # Branch B: DEFEX (unnumbered), after optional classes
    $defex = Search-DefEx -Tokens $Tokens -StartIndex $i
    if (-Not $defex.Found) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $defex.NextIndex
            WtDef       = $null
            Diagnostics = $diag + $defex.Diagnostics
        }
    }
    $i = $defex.NextIndex

    $node2 = [PSCustomObject]@{
        WordType = $wtTok.Content
        Classes     = $classes
        DefEx    = $defex.DefEx
    }

    return [PSCustomObject]@{
        Found     = $true
        NextIndex   = $i
        WtDef       = $node2
        Diagnostics = $diag
    }
}

function Search-WordDef {
    <#
        a WORDDEF may be either:
        - CEBWORD + one or more WORDDEFs (conjugations)
        - CEBWORD + one or more WTDEFs
        - CEBWORD + one or more NUMDEFs
        - CEBWORD + DEFEX + one or more WTDEFs
        - CEBWORD + DEFEX + one or more NUMDEFs
        - CEBWORD + DEFEX
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex;

    $headTok = Get-Token $Tokens $i
    if (-Not (IsType $headTok 'CEBWORD')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            WordDef     = $null
            Diagnostics = [PSCustomObject]@{
                Index=$i
                Message='WORDDEF: expected CEBWORD'
                Token=$headTok
            }
        }
    }
    $i++

    $tok = Get-Token $Tokens $i

    # one or more WORDDEFs (conjugations)
    $worddefs = @()
    if (IsType $tok 'CEBWORD') {
        while (IsType $tok 'CEBWORD') {
            $wd = Search-WordDef -Tokens $Tokens -StartIndex $i
            if ($wd.Found) {
                $worddefs += $wd.WordDef
                $i = $wd.NextIndex
                $tok = Get-Token $Tokens $i
            }
        }

        if ($worddefs.Count -gt 0) {
            return [PSCustomObject]@{
                Found   = $true
                NextIndex = $i
                WordDef   = [PSCustomObject]@{
                    Word         = $headTok.Content
                    Conjugations = $worddefs
                }
            }
        } else {
            return [PSCustomObject]@{
                Found     = $false
                NextIndex   = $i
                WordDef     = $null
                Diagnostics = [PSCustomObject]@{
                    Index=$i
                    Message='WORDDEF: could not parse WORDDEF after CEBWORD'
                    Token=$headTok
                }
            }
        }
    }

    # one or more WTDEFs
    if (IsType $tok 'WORDTYPE') {
        $wtdefs = @()
        while (IsType (Get-Token $Tokens $i) 'WORDTYPE') {
            $wtr = Set-WtDef -Tokens $Tokens -StartIndex $i
            if (-Not $wtr.Found) {
                return [PSCustomObject]@{
                    Found     = $false
                    NextIndex   = $wtr.NextIndex
                    WordDef     = $null
                    Diagnostics = $wtr.Diagnostics
                }
            }
            $wtdefs += $wtr.WtDef
            $i = $wtr.NextIndex
        }
        return [PSCustomObject]@{
            Found   = $true
            NextIndex = $i
            WordDef   = [PSCustomObject]@{
                Word         = $headTok.Content
                WordTypeDefs = $wtdefs
            }
            Diagnostics = $diag
        }
    }

    # one or more NUMDEFs
    if (IsType $tok 'NUMBER') {
        $numdefs = @()
        while (IsType (Get-Token $Tokens $i) 'NUMBER') {
            $nd = Set-NumDef -Tokens $Tokens -StartIndex $i
            if (-Not $nd.Found) {
                return [PSCustomObject]@{
                    Found     = $false
                    NextIndex   = $nd.NextIndex
                    WordDef     = $null
                    Diagnostics = $diag + $nd.Diagnostics
                }
            }
            $numdefs += $nd.NumDef
            $i = $nd.NextIndex
        }
        return [PSCustomObject]@{
            Found   = $true
            NextIndex = $i
            WordDef   = [PSCustomObject]@{
                Word         = $headTok.Content
                NumberedDefs = $numdefs
            }
            Diagnostics = $diag
        }
    }

    # DEFEX
    # DEFEX + one or more WTDEFs
    # DEFEX + one or more NUMDEFs
    $defex = Search-DefEx -Tokens $Tokens -StartIndex $i
    if ($defex.Found) {
        $i = $defex.NextIndex

        # If immediately followed by NUMBER, collect NUMDEF+
        if (IsType (Get-Token $Tokens $i) 'NUMBER') {
            $numdefs = @()
            while (IsType (Get-Token $Tokens $i) 'NUMBER') {
                $nd = Set-NumDef -Tokens $Tokens -StartIndex $i
                if (-Not $nd.Found) {
                    return [PSCustomObject]@{
                        Found     = $false
                        NextIndex   = $nd.NextIndex
                        WordDef     = $null
                        Diagnostics = $diag + $defex.Diagnostics + $nd.Diagnostics
                    }
                }
                $numdefs += $nd.NumDef
                $i = $nd.NextIndex
            }

            return [PSCustomObject]@{
                Found   = $true
                NextIndex = $i
                WordDef   = [PSCustomObject]@{
                    Word            = $headTok.Content
                    defex           = $defex.DefEx
                    NumberedDefs    = $numdefs
                }
            }
        }

        # one or more WTDEFs
        if (IsType $tok 'WORDTYPE') {
            $wtdefs = @()
            while (IsType (Get-Token $Tokens $i) 'WORDTYPE') {
                $wtr = Set-WtDef -Tokens $Tokens -StartIndex $i

                # failed to collect
                if (-Not $wtr.Found) {
                    return [PSCustomObject]@{
                        Found     = $false
                        NextIndex   = $wtr.NextIndex
                        WordDef     = $null
                        Diagnostics = $wtr.Diagnostics
                    }
                }
                $wtdefs += $wtr.WtDef
                $i = $wtr.NextIndex
            }

            return [PSCustomObject]@{
                Found   = $true
                NextIndex = $i
                WordDef   = [PSCustomObject]@{
                    Word         = $headTok.Content
                    WordTypeDefs = $wtdefs
                }
                Diagnostics = $diag
            }
        }

        # Otherwise: DEFEX-only
        return [PSCustomObject]@{
            Found   = $true
            NextIndex = $i
            WordDef   = [PSCustomObject]@{
                Word     = $headTok.Content
                DefEx    = $defex.DefEx
            }
            Diagnostics = $diag
        }
    }

    # If DEFEX failed here, we treat it as a hard failure for WORDDEF
    return [PSCustomObject]@{
        Found     = $false
        NextIndex   = $defex.NextIndex
        WordDef     = $null
        Diagnostics = $diag + $defex.Diagnostics + [PSCustomObject]@{
            Index   = $defex.NextIndex
            Message = 'WORDDEF: expected DEFEX|([DEFEX] WORDDEF+|WTDEF+|NUMDEF+)'
            Token   = Get-Token $Tokens $defex.NextIndex
        }
    }
}

# after the word, there may be one or more types (e.g. <i>n</i>, <i>v</i>, <i>a</i>)
# then each type may have one or more numbered definitions
# and a definition may be a conjugation
# then after all numbered definitions there may be one or more conjugations
# which also may have zero or more types of its own
# and may also have zero or more numbered definitions
# there may be a conjugation that is part of a definition (e.g. after the word type or the word conjugation)

# more formally:

# a DEF (definition) is:
#   - zero or more CLASS + one or more TEXT or LINK
# LET EX (example) be a CEBPHRASE (cebuano phrase block) + TEXT (assumed to be english) (note: this should also be terminating with a peridd)
#   - TODO: the CEBPHRASE may have a comma (or ! or ?) and the english text should end with a period (or ! or ?)
#   - if the parsing becomes difficult, consider using punctuation as a sanity-test
# let a DEFEX be a block of DEF + zero or more EX
# let NUMDEF (numbered definition) be NUMBER + DEFEX
# let WTDEF (word type definition) be either:
#   - WORDTYPE (noun, verb, adj) + DEFEX
#   - WORDTYPE (noun, verb, adj) + DEFEX + one or more NUMDEFs
#   - WORDTYPE (noun, verb, adj) + one or more NUMDEFs
# let WORDDEF (word definition) be either:
#   - CEBWORD + one or more WORDDEFs (conjugations)
#   - CEBWORD + one or more WTDEFs
#   - CEBWORD + one or more NUMDEFs
#   - CEBWORD + DEFEX + one or more WTDEFs
#   - CEBWORD + DEFEX + one or more NUMDEFs
#   - CEBWORD + DEFEX
# each row will have one or more WORDDEF

function Search-Definition {
    <#
      ROW ::= WORDDEF+ (word definiton then conjugations)
      Found = consumed all tokens AND at least one WORDDEF produced, each subsequent worddef considered to be an affix
      Returns {Found, NextIndex, Row:{WordDefs[]}, Diagnostics}
    #>
    param(
        [object[]]$Tokens
    )
    $i = 0; $diag = @(); $worddefs = @()

    while ($i -lt $Tokens.Count) {
        $wd = Search-WordDef -Tokens $Tokens -StartIndex $i
        if (-Not $wd.Found) {
            $diag += $wd.Diagnostics
            break
        }
        $worddefs += $wd.WordDef
        $i = $wd.NextIndex

        # If next token is not a WORDTYPE/NUMBER/DEFEX starter or new CEBWORD,
        # we either reached end or hit unexpected trailing material.
        $next = Get-Token $Tokens $i
        if (-Not $next) { break }

        # If next begins another WORDDEF (CEBWORD), continue loop.
        if (IsType $next 'CEBWORD') { continue }

        # Otherwise, if we see legal continuations (e.g., more WTDEF/NUMDEF),
        # they would have been consumed inside Search-WordDef; anything else is trailing.
        if ($next) {
            $diag += [PSCustomObject]@{
                Index=$i; Message="Trailing token after WORDDEF: $($next.Type)"; Token=$next
            }
            break
        }
    }

    $Found = ($i -eq $Tokens.Count) -and ($worddefs.Count -ge 1)

    $worddef = $worddefs | Select-Object -First 1
    $conjugations = $worddefs | Select-Object -Skip 1
    if ($conjugations) {
        $worddef | Add-Member -NotePropertyName Conjugations -NotePropertyValue $conjugations -Force
    }

    [PSCustomObject]@{
        WordDef      = $worddef
        Found      = [bool]$Found
        NextIndex    = $i
        Diagnostics  = $diag
    }
}