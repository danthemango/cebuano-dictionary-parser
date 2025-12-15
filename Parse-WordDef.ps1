# .Description
# parse a single word definition (a paragraph section in the dictionary)
# .EXAMPLE
# this script accepts an array of tokens per word group
# Import-Csv .\tokenlist.csv | Group-Object word | ForEach-Object { .\Parse.ps1 -Tokens $_.Group }
param (
    # accept array of tokens for the definition paragraph
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    $Tokens
)

function Get-Token {
    param([object[]]$Tokens, [int]$i)
    if ($i -ge 0 -and $i -lt $Tokens.Count) { $Tokens[$i] } else { $null }
}
function IsType {
    param($tok, [string]$type)
    $tok -and ($tok.Type -eq $type)
}

# parse a definiton
function Parse-Def {
    <#
      DEF ::= (TEXT | LINK)+
      Returns {Success, NextIndex, Def:{Text, Links[], Word}, Diagnostics}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $tok = Get-Token $Tokens $i
    if (-not $tok) {
        return [pscustomobject]@{ Success=$false; NextIndex=$i; Def=$null; Diagnostics=@(
            [pscustomobject]@{ Index=$i; Message='DEF: no token'; Token=$null }
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
        if (-not $tok) {
            break
        }
    }

    # # Case 3: CEBWORD
    # if (IsType $tok 'CEBWORD') {
    #     $word = $tok.Content; $i++
    #     return [pscustomobject]@{
    #         Success   = $true
    #         NextIndex = $i
    #         Def       = [pscustomobject]@{ Text=$null; Links=@(); Word=$word }
    #         Diagnostics = $diag
    #     }
    # }

    if ($text_link_arr.Count -eq 0) {
        [pscustomobject]@{
            Success     = $false
            NextIndex   = $i
            Def         = $null
            Diagnostics = $diag + [pscustomobject]@{ Index=$i; Message="DEF: unexpected $($tok.Type)"; Token=$tok }
        }
    } elseif ($text_link_arr.Count -eq 1) {
        [pscustomobject]@{
            Success     = $true
            NextIndex   = $i
            Def         = $text_link_arr[0]
            Diagnostics = $diag
        }
    } else {
        [pscustomobject]@{
            Success     = $true
            NextIndex   = $i
            Def         = $text_link_arr
            Diagnostics = $diag
        }
    }
}

function Parse-Example {
    <#
      EX ::= CEBPHRASE TEXT
      Returns {Success, NextIndex, Example:{Phrase, Gloss}, Diagnostics}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $phraseTok = Get-Token $Tokens $i
    if (-not $phraseTok -or -not ($phraseTok.Type -eq 'CEBPHRASE')) {
        return [pscustomobject]@{ Success=$false; NextIndex=$i; Example=$null; Diagnostics=$diag }
    }
    $i++

    $glossTok = Get-Token $Tokens $i
    if (-not (IsType $glossTok 'TEXT')) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $StartIndex     # roll back
            Example     = $null
            Diagnostics = $diag + [pscustomobject]@{
                Index=$i; Message='EX: expected TEXT after phrase'; Token=$glossTok
            }
        }
    }
    $i++

    [pscustomobject]@{
        Success   = $true
        NextIndex = $i
        Example   = [pscustomobject]@{
            Phrase = $phraseTok.Content
            Gloss  = $glossTok.Content
        }
        Diagnostics = $diag
    }
}

function Parse-Examples {
    <#
      Parse zero or more EX pairs.
      Returns {Examples[], NextIndex}
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex
    $examples = @()
    while ($true) {
        $ex = Parse-Example -Tokens $Tokens -StartIndex $i
        if (-not $ex.Success) { break }
        $examples += $ex.Example
        $i = $ex.NextIndex
    }
    [pscustomobject]@{ Examples=$examples; NextIndex=$i }
}

function Parse-DefEx {
    <#
      DEFEX ::= DEF EX*
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $def = Parse-Def -Tokens $Tokens -StartIndex $i
    if (-not $def.Success) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $def.NextIndex
            DefEx       = $null
            Diagnostics = $def.Diagnostics
        }
    }
    $i = $def.NextIndex

    $exs = Parse-Examples -Tokens $Tokens -StartIndex $i
    $i = $exs.NextIndex

    [pscustomobject]@{
        Success   = $true
        NextIndex = $i
        DefEx     = [pscustomobject]@{ Def=$def.Def; Examples=$exs.Examples }
        Diagnostics = $diag
    }
}

function Parse-NumDef {
    <#
      NUMDEF ::= NUMBER [CLASS] DEFEX
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $numTok = Get-Token $Tokens $i
    if (-not (IsType $numTok 'NUMBER')) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $i
            NumDef      = $null
            Diagnostics = $diag + [pscustomobject]@{ Index=$i; Message='NUMDEF: expected NUMBER'; Token=$numTok }
        }
    }
    $i++

    # collect CLASS
    $class = $null
    if (IsType (Get-Token $Tokens $i) 'CLASS') {
        $class += (Get-Token $Tokens $i).Content
        $i++
    }

    $defex = Parse-DefEx -Tokens $Tokens -StartIndex $i
    if (-not $defex.Success) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $defex.NextIndex
            NumDef      = $null
            Diagnostics = $diag + $defex.Diagnostics
        }
    }
    $i = $defex.NextIndex

    [pscustomobject]@{
        Success   = $true
        NextIndex = $i
        NumDef    = [pscustomobject]@{
            Number = $numTok.Content
            Class     = $class
            DefEx  = $defex.DefEx
        }
        Diagnostics = $diag
    }
}

function Parse-WtDef {
    <#
      WTDEF ::= WORDTYPE CLASS* ( NUMDEF+ | DEFEX )
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    # Require WORDTYPE
    $wtTok = Get-Token $Tokens $i
    if (-not (IsType $wtTok 'WORDTYPE')) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $i
            WtDef       = $null
            Diagnostics = $diag + [pscustomobject]@{
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
            $nd = Parse-NumDef -Tokens $Tokens -StartIndex $i
            if (-not $nd.Success) {
                return [pscustomobject]@{
                    Success     = $false
                    NextIndex   = $nd.NextIndex
                    WtDef       = $null
                    Diagnostics = $diag + $nd.Diagnostics
                }
            }
            $numdefs += $nd.NumDef
            $i = $nd.NextIndex
        }

        $node = [pscustomobject]@{
            WordType     = $wtTok.Content
            Classes      = $classes
            NumberedDefs = $numdefs
        }

        return [pscustomobject]@{
            Success     = $true
            NextIndex   = $i
            WtDef       = $node
            Diagnostics = $diag
        }
    }

    # Branch B: DEFEX (unnumbered), after optional classes
    $defex = Parse-DefEx -Tokens $Tokens -StartIndex $i
    if (-not $defex.Success) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $defex.NextIndex
            WtDef       = $null
            Diagnostics = $diag + $defex.Diagnostics
        }
    }
    $i = $defex.NextIndex

    $node2 = [pscustomobject]@{
        WordType = $wtTok.Content
        Classes     = $classes
        DefEx    = $defex.DefEx
    }

    return [pscustomobject]@{
        Success     = $true
        NextIndex   = $i
        WtDef       = $node2
        Diagnostics = $diag
    }
}

function Parse-WordDef {
    <#
      WORDDEF ::= CEBWORD (WTDEF+ | [DEFEX] NUMDEF+ | DEFEX) WORDDEF*
    #>
    param([object[]]$Tokens, [int]$StartIndex)
    $i = $StartIndex; $diag = @()

    $headTok = Get-Token $Tokens $i
    if (-not (IsType $headTok 'CEBWORD')) {
        return [pscustomobject]@{
            Success     = $false
            NextIndex   = $i
            WordDef     = $null
            Diagnostics = $diag + [pscustomobject]@{ Index=$i; Message='WORDDEF: expected CEBWORD'; Token=$headTok }
        }
    }
    $i++

    $tok = Get-Token $Tokens $i

    # Branch 1: WORDDEF+ (list of conjugations)
    $worddefs = @()
    if (IsType $tok 'CEBWORD') {
        while (IsType $tok 'CEBWORD') {
            $wd = Parse-WordDef -Tokens $Tokens -StartIndex $i
            if ($wd.Success) {
                $worddefs += $wd.WordDef
                $i = $wd.NextIndex
                $tok = Get-Token $Tokens $i
            }
        }

        if ($worddefs.Count -gt 0) {
            return [pscustomobject]@{
                Success   = $true
                NextIndex = $i
                WordDef   = [pscustomobject]@{
                    Word         = $headTok.Content
                    Conjugations = $worddefs
                }
                Diagnostics = $diag
            }
        } else {
            return [pscustomobject]@{
                Success     = $false
                NextIndex   = $i
                WordDef     = $null
                Diagnostics = $diag + [pscustomobject]@{ Index=$i; Message='WORDDEF: could not parse WORDDEF after CEBWORD'; Token=$headTok }
            }
        }
    }

    # Branch 2: WTDEF+
    if (IsType $tok 'WORDTYPE') {
        $wtdefs = @()
        while (IsType (Get-Token $Tokens $i) 'WORDTYPE') {
            $wtr = Parse-WtDef -Tokens $Tokens -StartIndex $i
            if (-not $wtr.Success) {
                return [pscustomobject]@{
                    Success     = $false
                    NextIndex   = $wtr.NextIndex
                    WordDef     = $null
                    Diagnostics = $diag + $wtr.Diagnostics
                }
            }
            $wtdefs += $wtr.WtDef
            $i = $wtr.NextIndex
        }
        return [pscustomobject]@{
            Success   = $true
            NextIndex = $i
            WordDef   = [pscustomobject]@{
                Word         = $headTok.Content
                WordTypeDefs = $wtdefs
            }
            Diagnostics = $diag
        }
    }

    # Branch 3a: NUMDEF+ (no leading DEFEX)
    if (IsType $tok 'NUMBER') {
        $numdefs = @()
        while (IsType (Get-Token $Tokens $i) 'NUMBER') {
            $nd = Parse-NumDef -Tokens $Tokens -StartIndex $i
            if (-not $nd.Success) {
                return [pscustomobject]@{
                    Success     = $false
                    NextIndex   = $nd.NextIndex
                    WordDef     = $null
                    Diagnostics = $diag + $nd.Diagnostics
                }
            }
            $numdefs += $nd.NumDef
            $i = $nd.NextIndex
        }
        return [pscustomobject]@{
            Success   = $true
            NextIndex = $i
            WordDef   = [pscustomobject]@{
                Word         = $headTok.Content
                NumberedDefs = $numdefs
            }
            Diagnostics = $diag
        }
    }

    # Branch 3b: optional leading DEFEX, then NUMDEF+ (if present)
    # If the next token is not WORDTYPE/NUMBER, attempt DEFEX
    $defexLead = Parse-DefEx -Tokens $Tokens -StartIndex $i
    if ($defexLead.Success) {
        $i = $defexLead.NextIndex

        # If immediately followed by NUMBER, collect NUMDEF+
        if (IsType (Get-Token $Tokens $i) 'NUMBER') {
            $numdefs = @()
            while (IsType (Get-Token $Tokens $i) 'NUMBER') {
                $nd = Parse-NumDef -Tokens $Tokens -StartIndex $i
                if (-not $nd.Success) {
                    return [pscustomobject]@{
                        Success     = $false
                        NextIndex   = $nd.NextIndex
                        WordDef     = $null
                        Diagnostics = $diag + $defexLead.Diagnostics + $nd.Diagnostics
                    }
                }
                $numdefs += $nd.NumDef
                $i = $nd.NextIndex
            }

            return [pscustomobject]@{
                Success   = $true
                NextIndex = $i
                WordDef   = [pscustomobject]@{
                    Word            = $headTok.Content
                    DefExLead       = $defexLead.DefEx
                    NumberedDefs    = $numdefs
                }
                Diagnostics = $diag
            }
        }

        # Otherwise: DEFEX-only
        return [pscustomobject]@{
            Success   = $true
            NextIndex = $i
            WordDef   = [pscustomobject]@{
                Word     = $headTok.Content
                DefEx    = $defexLead.DefEx
            }
            Diagnostics = $diag
        }
    }

    # If DEFEX failed here, we treat it as a hard failure for WORDDEF
    return [pscustomobject]@{
        Success     = $false
        NextIndex   = $defexLead.NextIndex
        WordDef     = $null
        Diagnostics = $diag + $defexLead.Diagnostics + [pscustomobject]@{
            Index   = $defexLead.NextIndex
            Message = 'WORDDEF: expected WTDEF+, NUMDEF+, or DEFEX'
            Token   = Get-Token $Tokens $defexLead.NextIndex
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

# a DEF (definition) is (optional) CLASS + TEXT or LINK or (TEXT+LINK) or CEBWORD
# LET EX (example) be a CEBPHRASE (cebuano phrase block) + TEXT (assumed to be english)
# let a DEFEX be a block of DEF + a list of zero or more EX
# let NUMDEF be a NUMBER followed by DEFEX
# let WTDEF (word type definition) be a WORDTYPE (noun, verb) follow by a DEFEX or list of NUMDEFS
# let WORDDEF (word definition) be either
# - a CEBWORD + a list of one or more WTDEF
# - a CEBWORD + a list of one or more NUMDEF
# - a CEBWORD + DEFEX + a list of one or more NUMDEF
# - a CEBWORD + DEFEX
# each row will have one or more WORDDEF

function Parse-Row {
    <#
      ROW ::= WORDDEF+ (word definiton then conjugations)
      Success = consumed all tokens AND at least one WORDDEF produced, each subsequent worddef considered to be an affix
      Returns {Success, NextIndex, Row:{WordDefs[]}, Diagnostics}
    #>
    param([object[]]$Tokens)
    $i = 0; $diag = @(); $worddefs = @()

    while ($i -lt $Tokens.Count) {
        $wd = Parse-WordDef -Tokens $Tokens -StartIndex $i
        if (-not $wd.Success) {
            $diag += $wd.Diagnostics
            break
        }
        $worddefs += $wd.WordDef
        $i = $wd.NextIndex

        # If next token is not a WORDTYPE/NUMBER/DEFEX starter or new CEBWORD,
        # we either reached end or hit unexpected trailing material.
        $next = Get-Token $Tokens $i
        if (-not $next) { break }

        # If next begins another WORDDEF (CEBWORD), continue loop.
        if (IsType $next 'CEBWORD') { continue }

        # Otherwise, if we see legal continuations (e.g., more WTDEF/NUMDEF),
        # they would have been consumed inside Parse-WordDef; anything else is trailing.
        if ($next) {
            $diag += [pscustomobject]@{
                Index=$i; Message="Trailing token after WORDDEF: $($next.Type)"; Token=$next
            }
            break
        }
    }

    $success = ($i -eq $Tokens.Count) -and ($worddefs.Count -ge 1)

    $worddef = $worddefs | Select-Object -First 1
    $conjugations = $worddefs | Select-Object -Skip 1
    if ($conjugations) {
        $worddef | Add-Member -NotePropertyName Conjugations -NotePropertyValue $conjugations -Force
    }

    [pscustomobject]@{
        Success      = [bool]$success
        NextIndex    = $i
        WordDef      = $worddef
        Diagnostics  = $diag
    }
}

# Parse the normalized token array into a structured tree
$res = Parse-Row -Tokens $Tokens

[pscustomobject] @{
    Tokens           = $Tokens
    WordDef          = $res.WordDef
    ParseOk          = $res.Success
    ParseNextIndex   = $res.NextIndex
    ParseDiagnostics = $res.Diagnostics
}

# $successfuls = $parsed | Where-Object { $_.ParseOk }
# $faileds = $parsed | Where-Object { -not $_.ParseOk }

# # Finally, write the whole set to JSON
# $faileds |
#     ConvertTo-Json -Depth 100 |
#     Set-Content -Encoding UTF8 -Path "failed-parse.json"

# # $successfuls.WordDef |
# $successfuls |
#     ConvertTo-Json -Depth 100 |
#     Set-Content -Encoding UTF8 -Path "successful-parse.json"
