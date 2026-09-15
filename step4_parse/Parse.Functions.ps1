function Get-Token {
    param(
        [object[]]$Tokens,
        [int]$Index
    )
    $i = $Index
    if ($i -ge 0 -and $i -lt $Tokens.Count) {
        $Tokens[$i]
    } else {
        $null
    }
}

<#
.DESCRIPTION
    returns true if the token has a given type
#>
function IsType {
    param(
        $Token,
        [string]$Type
    )
    $Token -and ($Token.Type -eq $Type)
}

<#
.DESCRIPTION
    parse definition
#>
function Search-Def {
    <#
      DEF ::= [Class] (TEXT | LINK)+
      Returns {Found, NextIndex, Def:{Text, Links[], Word}, Diagnostics}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex;

    $tok = Get-Token $Tokens $i
    if (-Not $tok) {
        return [PSCustomObject]@{ Found=$false; NextIndex=$i; Def=$null; Diagnostics=@(
            [PSCustomObject]@{ Index=$i; Message='DEF: no token'; Token=$null }
        ) }
    }

    # [class]
    $classes = $null
    if (IsType (Get-Token $Tokens $i) 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
        $i++
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

    if ($text_link_arr.Count -eq 0) {
        [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            Def         = $null
            Diagnostics = @(
                [PSCustomObject]@{
                    Index=$i;
                    Message="DEF: unexpected $($tok.Type)";
                    Token=$tok
                }
            )
        }
    } elseif ($text_link_arr.Count -eq 1) {
        [PSCustomObject]@{
            Found     = $true
            NextIndex   = $i
            Classes       = $classes
            Def         = $text_link_arr[0]
        }
    } else {
        [PSCustomObject]@{
            Found     = $true
            NextIndex   = $i
            Classes       = $classes
            Def         = $text_link_arr
        }
    }
}

function Search-Example {
    <#
      EX ::= CEBPHRASE TEXT
      Returns {Found, NextIndex, Example:{Phrase, Gloss}, Diagnostics}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex;

    $phraseTok = Get-Token $Tokens $i
    if (-Not $phraseTok -or -Not ($phraseTok.Type -eq 'CEBPHRASE')) {
        return [PSCustomObject]@{
            Found=$false;
            NextIndex=$i;
            Example=$null;
        }
    }
    $i++

    $glossTok = Get-Token $Tokens $i
    if (-Not (IsType $glossTok 'TEXT')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $StartIndex     # roll back
            Example     = $null
            Diagnostics = @(
                [PSCustomObject]@{
                    Index=$i; Message='EX: expected TEXT after phrase'; Token=$glossTok
                }
            )
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
    }
}

function Search-Examples {
    <#
      Parse zero or more EX pairs.
      Returns {Examples[], NextIndex}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex
    $examples = @()
    while ($true) {
        $ex = Search-Example -Tokens $Tokens -StartIndex $i
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
    param(
        [object[]]$Tokens,
        [int]$StartIndex
    )
    $i = $StartIndex;

    $def = Search-Def -Tokens $Tokens -StartIndex $i
    if (-Not $def.Found) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $def.NextIndex
            DefEx       = $null
            Diagnostics = $def.Diagnostics
        }
    }
    $i = $def.NextIndex

    $exs = Search-Examples -Tokens $Tokens -StartIndex $i
    $i = $exs.NextIndex

    [PSCustomObject]@{
        Found   = $true
        NextIndex = $i
        Def     = [PSCustomObject]@{
            Def=$def.Def;
            Examples=$exs.Examples
        }
    }
}

function Search-NumDef {
    <#
        NUMDEF may be either:
        - Number + DEFEX
        - Number + CEBWORD
        - Number + CEBWORD + DEFEX
    #>
    param(
        [object[]]$Tokens,
        [int]$StartIndex
    )
    $i = $StartIndex;

    $numTok = Get-Token $Tokens $i
    if (-Not (IsType $numTok 'NUMBER')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            NumDef      = $null
            Diagnostics = @(
                [PSCustomObject]@{ Index = $i; Message = 'NUMDEF: expected NUMBER'; Token = $numTok }
            )
        }
    }
    $i++

    $found = $false
    $numDef = [PSCustomObject]@{
        Number = $numTok.Content
    }

    # classes
    $classes = @()
    while (IsType (Get-Token $Tokens $i) 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
        $i++
    }

    # cebword
    $tok = Get-Token $Tokens $i
    if (IsType -Token $tok -Type "CEBWORD") {
        $numDef | Add-Member -NotePropertyName CebWord -NotePropertyValue $tok.Content -Force
        $found = $true
        $i++
    }

    # find any classes after cebword
    while (IsType (Get-Token $Tokens $i) 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
        $i++
    }
    if ($classes.Count -gt 0) {
        $numDef | Add-Member -NotePropertyName Classes -NotePropertyValue $classes -Force
    }

    # defex
    $defex = Search-DefEx -Tokens $Tokens -StartIndex $i
    if ($defex.Found) {
        $numDef | Add-Member -NotePropertyName DefEx -NotePropertyValue $defex.Def -Force
        $found = $true
        $i = $defex.NextIndex
    }

    # accept a nested number def if no defex found
    if (-Not $defex.Found) {
        $subNumDefs = @()
        $subNumDef = Search-NumDef -Tokens $Tokens -StartIndex $i
        while ($subNumDef.Found) {
            $subNumDefs += $subNumDef.NumDef
            $found = $true
            $i = $subNumDef.NextIndex
            $subNumDef = Search-NumDef -Tokens $Tokens -StartIndex $i
        }
        if ($subNumDefs.Count -gt 0) {
            $numDef | Add-Member -NotePropertyName NumDefs -NotePropertyValue $subNumDefs -Force
        }
    }

    # if no defex or subnumdefs found, see if a wtdef can be parsed
    if ((-Not $defex.Found) -and ($subNumDefs.Count -eq 0)) {
        $wtdefs = @()
        while (IsType (Get-Token $Tokens $i) 'WORDTYPE') {
            $wtDef = Search-WtDef -Tokens $Tokens -StartIndex $i
            if ($wtDef.Found) {
                $wtdefs += $wtDef.Def
                $found = $True
                $i = $wtDef.NextIndex
            } else {
                break
            }
        }
        if ($wtdefs.Count -gt 0) {
            $numDef | Add-Member -NotePropertyName WordTypeDefs -NotePropertyValue $wtdefs -Force
        }
    }

    if ($found) {
        return [PSCustomObject]@{
            Found     = $true
            NextIndex   = $i
            NumDef      = $numDef
        }
    } else {
        return [PSCustomObject]@{
            Found       = $false
            Diagnostics = @(
                [PSCustomObject]@{ Index = $i; Message = 'NUMDEF: could not parse token.'; Token = $numTok }
            )
        }
    }
}

function Search-WtDef {
    <#
      WTDEF ::= WORDTYPE CLASS* [CEBWORD] ( NUMDEF+ | DEFEX )
      a word type def may have a class, and must have either have a cebword, a defex, one or more numdefs, or both
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex;

    # Require WORDTYPE
    $wtTok = Get-Token $Tokens $i
    if (-Not (IsType $wtTok 'WORDTYPE')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            WtDef       = $null
            Diagnostics = @(
                [PSCustomObject]@{
                    Index = $i; Message = 'WTDEF: expected WORDTYPE'; Token = $wtTok
                }
            )
        }
    }
    $i++

    # collect CLASS*
    $classes = @()
    while (IsType (Get-Token $Tokens $i) 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
        $i++
    }

    # it may have a cebword in this position
    $tok = Get-Token $Tokens $i
    $cebword = $null
    if (IsType $tok 'CEBWORD') {
        $cebword = $tok.Content
        $i++
    }

    $defex = Search-DefEx -Tokens $Tokens -StartIndex $i
    if ($defex.Found) {
        $i = $defex.NextIndex
    }

    $numdefs = @()
    while (IsType (Get-Token $Tokens $i) 'NUMBER') {
        $nd = Search-NumDef -Tokens $Tokens -StartIndex $i
        if ($nd.Found) {
            $numdefs += $nd.NumDef
            $i = $nd.NextIndex
        } else {
            break
        }
    }

    if (($null -eq $cebword) -And ($numdefs.Count -eq 0) -And (-Not $defex.Found)) {
        return [PSCustomObject]@{
            Found       = $false
            NextIndex   = $i
            Def         = $null
            Diagnostics = @(
                [PSCustomObject]@{
                    Index = $i
                    Message = 'WTDEF: could not parse'
                    Token = $tok
                }
            )
        }
    }

    $def = [PSCustomObject]@{
        WordType = $wtTok.Content
    }
    if ($null -ne $cebword) {
        $def | Add-Member -NotePropertyName CebWord -NotePropertyValue $cebword -Force
    }
    if ($classes.Count -gt 0) {
        $def | Add-Member -NotePropertyName Classes -NotePropertyValue $classes -Force
    }
    if ($defex.Found) {
        $def | Add-Member -NotePropertyName DefEx -NotePropertyValue $defex.Def -Force
    }
    if ($numdefs.Count -gt 0) {
        $def | Add-Member -NotePropertyName NumberedDefs -NotePropertyValue $numdefs -Force
    }

    return [PSCustomObject]@{
        Found        = $true
        NextIndex    = $i
        Def          = $def
    }
}

function Search-DefBody {
    <#
        a DefBody may be either:
        - CEBWORD + [CLASS] + one or more WORDDEFs (conjugations)
        - CEBWORD + [CLASS] + one or more WTDEFs
        - CEBWORD + [CLASS] + one or more NUMDEFs
        - CEBWORD + [CLASS] + DEFEX + one or more WTDEFs
        - CEBWORD + [CLASS] + DEFEX + one or more NUMDEFs
        - CEBWORD + [CLASS] + DEFEX
    #>
    param(
        [object[]]$Tokens,
        [int]$StartIndex
    )
    $i = $StartIndex;

    # a DefBody must begin with a CEBWORD
    $headTok = Get-Token $Tokens $i
    if (-Not (IsType $headTok 'CEBWORD')) {
        return [PSCustomObject]@{
            Found     = $false
            NextIndex   = $i
            DefBody     = $null
            Diagnostics = [PSCustomObject]@{
                Index=$i
                Message='DefBody: expected CEBWORD'
                Token=$headTok
            }
        }
    }
    $i++

    $tok = Get-Token $Tokens $i

    $found = $False
    $def = [PSCustomObject]@{
        Word = $headTok.Content
    }

    # [class]+
    $classes = @()
    while (IsType $tok 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
        $i++
        $tok = Get-Token $Tokens $i
    }
    if ($classes.Count -gt 0) {
        $def | Add-Member -NotePropertyName Classes -NotePropertyValue $classes -Force
    }

    $defex = Search-DefEx -Tokens $Tokens -StartIndex $i
    if ($defex.Found) {
        $found = $True
        $def | Add-Member -NotePropertyName DefEx -NotePropertyValue $defex.Def -Force
        $i = $defex.NextIndex
    }

    $numdefs = @()
    while (IsType (Get-Token $Tokens $i) 'NUMBER') {
        $nd = Search-NumDef -Tokens $Tokens -StartIndex $i
        if ($nd.Found) {
            $found = $True
            $numdefs += $nd.NumDef
            $i = $nd.NextIndex
        } else {
            break
        }
    }
    if ($numdefs.Count -gt 0) {
        $def | Add-Member -NotePropertyName NumberedDefs -NotePropertyValue $numdefs -Force
    }

    $wtdefs = @()
    while (IsType (Get-Token $Tokens $i) 'WORDTYPE') {
        $wtDef = Search-WtDef -Tokens $Tokens -StartIndex $i
        if ($wtDef.Found) {
            $found = $True
            $wtdefs += $wtDef.Def
            $i = $wtDef.NextIndex
        } else {
            break
        }
    }
    if ($wtdefs.Count -gt 0) {
        $def | Add-Member -NotePropertyName WordTypeDefs -NotePropertyValue $wtdefs -Force
    }

    $diagnostics = $null
    if (-Not $found) {
        $diagnostics = [PSCustomObject]@{
            Index   = $defex.NextIndex
            Message = 'Error parsing DefBody'
            Token   = Get-Token $Tokens $defex.NextIndex
        }
        $i = $StartIndex
    }

    return [PSCustomObject]@{
        Found       = $found
        NextIndex   = $i
        Def         = $def
        Diagnostics = $diagnostics
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
# let DefBody (word definition) be either:
#   - CEBWORD +
#   - CEBWORD + one or more WTDEFs
#   - CEBWORD + one or more NUMDEFs
#   - CEBWORD + DEFEX + one or more WTDEFs
#   - CEBWORD + DEFEX + one or more NUMDEFs
#   - CEBWORD + DEFEX
# each row will have one or more DefBody

function Search-WordDef {
    <#
      a word definition has either: a DefBody, one or more CEBWORD + DefBody pairs (conjugations), or both
      Found = consumed all tokens AND at least one DefBody produced, each subsequent DefBody considered to be an affix
      Returns {Found, NextIndex, Row:{WordDefs[]}, Diagnostics}
    #>
    param(
        [object[]]$Tokens
    )
    $i = 0;

    [object[]]$diag = @()

    $conjugations = @()
    $def = [PSCustomObject]@{ }
    $defBody = Search-DefBody -Tokens $Tokens -StartIndex $i
    if ($defBody.Found) {
        $def | Add-Member -NotePropertyName Def -NotePropertyValue $defBody.Def -Force
        $i = $defBody.NextIndex
    } else {
        # else we will assume everything else is just a list of conjugations
        $i++
    }

    while ($i -lt $Tokens.Count) {
        $conj = Search-DefBody -Tokens $Tokens -StartIndex $i
        if ($conj.Found) {
            $conjugations += $conj.Def
            $i = $conj.NextIndex
        } else {
            break
        }
    }

    # we have found a proper word definition if we have consumed all tokens and discovered either a defBody, one or more conjugations, or both
    $Found = ($i -eq $Tokens.Count) -and (($defBody.Found) -or ($conjugations.Count -gt 0))
    if (-Not $Found) {
        $next = Get-Token $Tokens $i
        $diag += [PSCustomObject]@{
            Index=$i; Message="Trailing token after DefBody: $($next.Type)"; Token=$next
        }
    }

    if ($conjugations.Count -gt 0) {
        $def | Add-Member -NotePropertyName Conjugations -NotePropertyValue $conjugations -Force
    }

    [PSCustomObject]@{
        WordDef      = $def
        Found        = [bool]$Found
        NextIndex    = $i
        Diagnostics  = $diag
    }
}