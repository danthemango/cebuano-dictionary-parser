# .EXAMPLE
# .\HTML-to-XML.ps1 | .\Parse-Dict.ps1 -Limit 20
param (
    # accept input as xml object piped in, mandatory
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    [xml]$inxml = $null,
    # limit the number of paragraphs to parse for testing
    # set Limit = $null for no limit
    [Parameter(Mandatory=$true)]
    [int]$Limit
)

# after the word, there may be one or more types (e.g. <i>n</i>, <i>v</i>, <i>a</i>)
# then each type may have one or more numbered definitions
# and a definition may be a conjugation
# then after all numbered definitions there may be one or more conjugations
# which also may have zero or more types of its own
# and may also have zero or more numbered definitions
# there may be a conjugation that is part of a definition (e.g. after the word type or the word conjugation)

# Utility function to convert multiple whitespace to single space
function reduceWS($text) {
    return ($text -replace "\s+", " ").Trim()
}

# strip pagenums from content
# <span class="pagenum">[<a id="xd20e22720" href="#xd20e22720">40</a>]</span>
function Remove-PageNums {
    param (
        [Parameter(Mandatory=$true)]
        [string]$content
    )

    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    return [regex]::Replace($content, '<span[^>]*class="pagenum"[^>]*>.*?</span>', '', $opts)
}

# look for paragraphs inside of each letter div
function Split-Paragraphs {
    param (
        [Parameter(ValueFromPipeline=$true)]
        [xml]$inxml
    )

    foreach ($section in Select-Xml -Xml $inxml -XPath "//div[@class='div1 letter']") {
        foreach ($node in $section.Node) {
            # strip the text 'letter.' from id:
            $letter = $node.id -replace "^letter\.", ""

            $divBodies = $node.ChildNodes | Where-Object class -eq divBody
            foreach ($divBody in $divBodies) {
                foreach ($para in $divBody.p) {
                    $content = $para.InnerXML

                    # remove page numbers
                    $content = Remove-PageNums $content

                    # reduce whitespace
                    $content = reduceWS($content)

                    # set content as a token of type text
                    $contentToken = [PSCustomObject]@{
                        Type  = "TEXT"
                        Content  = $content
                    }

                    [PSCustomObject]@{
                        letter  = $letter
                        tokens = @($contentToken)
                    }
                }
            }
        }
    }
}

function Split-TokensByPattern {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token,

        [Parameter(Mandatory=$true)]
        [string]$pattern,

        [Parameter(Mandatory=$true)]
        [string]$tokenType
    )
    process {
        # If not a TEXT token, pass through unchanged
        if ($token.Type -ne "TEXT") {
            $token
            return
        }

        $content = $token.Content
        $splits = [regex]::Split($content, $pattern)

        # If no matches (only one part after split), return original token
        if ($splits.Count -le 1) {
            $token
            return
        }

        # Output content before first match
        if ($splits[0].Trim() -ne "") {
            [PSCustomObject]@{
                Type    = "TEXT"
                Content = reduceWS($splits[0])
            }
        }

        # Alternating: captured group (the match), then content after it
        for ($i = 1; $i -lt $splits.Count; $i += 2) {
            # Output the matched token (e.g., NUMBER)
            [PSCustomObject]@{
                Type    = $tokenType
                Content = $splits[$i]
            }

            # Output content after this match
            $afterMatch = if ($i + 1 -lt $splits.Count) { $splits[$i + 1] } else { "" }
            if ($afterMatch.Trim() -ne "") {
                [PSCustomObject]@{
                    Type    = "TEXT"
                    Content = reduceWS($afterMatch)
                }
            }
        }
    }
}

# parses a def number, e.g. <b>1</b>, <b>2</b>, <b>2a</b>
# accept as input an array of tokens, and for each text token
# return the number tokens and text tokens for all text found between them
function Split-Nums {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        $token | Split-TokensByPattern -pattern "<b>(\d+[a-z]?)</b>" -tokenType "NUMBER"
    }
}

# parse word types / parts of speech
# e.g. nouns (<i>n</i>), verbs (<i>v</i>), adjectives (<i>a</i>), etc.
function Split-Types {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        $token | Split-TokensByPattern -pattern "<i>([anv])</i>" -tokenType "WORDTYPE"
    }
}

# find other words that are included
# they may be separate conjugations listed with their own definitions (including definition types and numbers)
# other words, variations, conjugations, affixes
# <b lang="ceb">adtuúnun, aladtúun</b>
function Split-Cebuano-Words {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        $pattern1 = "<b lang=""ceb"">\s*(.*?)\s*</b>"
        # the id is likely used to be the target of the internal links, not sure if that information can be used later.
        $pattern2 = "<b id=""[^""]+"" lang=""ceb"">\s*(.*?)\s*</b>"

        $token | Split-TokensByPattern -pattern $pattern1 -tokenType "CEBWORD" | Split-TokensByPattern -pattern $pattern2 -tokenType "CEBWORD"
    }
}

# find cebuano phrases
# e.g.:
# <i lang=""ceb"">Dakúa uy!</i>
function Split-Cebuano-Phrases {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        $token | Split-TokensByPattern -pattern '<i lang="ceb">(.*?)</i>' -tokenType "CEBPHRASE"
    }
}

# there are also latin words marked, such as:
# <b lang="la"><i>Musa textilis</i></b>.
# <b lang="la"><i>Balamcanda chinensis</i></b>.
# <b lang="la"><i>Eurycles amboinensis</i></b>.
# <b lang="la"><i>Persea sp</i></b>.
# but only a few, and usually are part of a definition.

# find other words that are being linked to
# the links are in a span with class "sc", and may or may not be in an <a> (which may be discarded)
# I'd like to add a new field "links", which is a semicolon-separated list of words that are linked to this one
# removing the "=", the "short for", and the "see" words before and the optional dot at the end.
# e.g.:
# = <span class="sc" lang="ceb"><a href="#balbal">balbal</a></span>.
# short for <span class="sc" lang="ceb"><a href="#niadtu">niadtu</a></span>.
# <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>.
function Split-Links {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        # If not a TEXT token, pass through unchanged
        if ($token.Type -ne "TEXT") {
            $token
            return
        }

        $content = $token.Content
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline

        # Pattern: <span class="sc" ...>...</span> with optional <a> inside
        $pattern = '<span[^>]*class="sc"[^>]*>.*?</span>'

        $splits = [regex]::Split($content, $pattern)
        $matches = [regex]::Matches($content, $pattern, $opts)

        # If no matches, return original token
        if ($matches.Count -eq 0) {
            $token
            return
        }

        # Output content before first match (with prefix cleanup)
        if ($splits[0].Trim() -ne "") {
            $beforeText = $splits[0]
            # Remove common prefixes and suffixes before links
            $beforeText = $beforeText -replace '\s*=\s*$', ''
            $beforeText = $beforeText -replace '<i[^>]*lang="ceb"[^>]*>\s*see\s*</i>\s*$', ''
            $beforeText = $beforeText -replace 'short for ?$', ''
            $beforeText = reduceWS($beforeText)

            if ($beforeText -ne "") {
                [PSCustomObject]@{
                    Type    = "TEXT"
                    Content = $beforeText
                }
            }
        }

        # Alternating: matched span, then content after it
        for ($i = 0; $i -lt $matches.Count; $i++) {
            $spanMatch = $matches[$i].Value

            # remove tags
            $linkText = $spanMatch -replace '<[^>]*>', ''
            $linkText = reduceWS($linkText)

            [PSCustomObject]@{
                Type    = "LINK"
                Content = $linkText
            }

            # Output content after this match
            $afterMatch = if ($i + 1 -lt $splits.Count) { $splits[$i + 1] } else { "" }
            if ($afterMatch.Trim() -ne "") {
                $afterText = $afterMatch
                # Clean up prefixes and suffixes
                $afterText = $afterText -replace '^\.?\s*', ''
                $afterText = reduceWS($afterText)

                if ($afterText -ne "") {
                    [PSCustomObject]@{
                        Type    = "TEXT"
                        Content = $afterText
                    }
                }
            }
        }
    }
}

# class
# <span class=""rm"">[A2; b3c]</span>
# <span class=""rm"">[<i lang=""ceb"">gen.</i>]</span>
function Split-Classes {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        $pattern = '<span class="rm">(.*?)</span>'
        $token | Split-TokensByPattern -pattern $pattern -tokenType "CLASS"
    }
}

# remove corr elements, leaving the text contents if there are any non-numbers
# <span class="corr" id="xd20e4931" title="Source: kunsididirasiyun">kunsidirasiyun</span>
# <span class="corr" id="xd20e5140" title="Not in source"><sub>1</sub></span>
function Strip-Corr {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        # If not a TEXT token, pass through unchanged
        if ($token.Type -ne "TEXT") {
            $token
            return
        }

        $content = $token.Content
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline

        # Pattern: <span class="corr" ...>...</span>
        $pattern = '<span[^>]*class="corr"[^>]*>.*?</span>'
        $splits = [regex]::Split($content, $pattern)
        $matches = [regex]::Matches($content, $pattern, $opts)
        # If no matches, return original token
        if ($matches.Count -eq 0) {
            $token
            return
        }

        # if there are any matches, remove the span (and sub) tags from the text but leave the content in-place
        $newContent = ""
        for ($i = 0; $i -lt $matches.Count; $i++) {
            $newContent += $splits[$i]

            $spanMatch = $matches[$i].Value
            # remove tags
            $innerText = $spanMatch -replace '<[^>]*>', ''
            # check if innerText has any non-numeric characters
            if ($innerText -match '\D') {
                $newContent += $innerText
            }
            # emit the content including before and after
            [PSCustomObject]@{
                Type    = "TEXT"
                Content = reduceWS($newContent)
            }
        }
    }
}

# strip punctuation and whitespace only text segments
# they are from text formatting and usually don't help with definitions or examples
function Strip-Punct {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        # If not a TEXT token, pass through unchanged
        if ($token.Type -ne "TEXT") {
            $token
            return
        }

        $content = $token.Content
        # If content is only punctuation or whitespace, skip it
        if ($content -match '^[\s\.,;:!\?\-()"\'']*$') {
            return
        }

        # Otherwise, emit the token unchanged
        $token
    }
}

function Get-Token {
    param([object[]]$Tokens, [int]$i)
    if ($i -ge 0 -and $i -lt $Tokens.Count) { $Tokens[$i] } else { $null }
}
function IsType { param($tok, [string]$type) $tok -and ($tok.Type -eq $type) }

function Parse-Def {
    <#
      DEF ::= TEXT [LINK*] | LINK+ | CEBWORD
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

    # Case 1: TEXT with optional LINKs
    if (IsType $tok 'TEXT') {
        $text = $tok.Content; $i++
        $links = @()
        while ($true) {
            $linkTok = Get-Token $Tokens $i
            if (-not (IsType $linkTok 'LINK')) { break }
            $links += $linkTok.Content
            $i++
        }
        return [pscustomobject]@{
            Success   = $true
            NextIndex = $i
            Def       = [pscustomobject]@{ Text=$text; Links=$links; Word=$null }
            Diagnostics = $diag
        }
    }

    # Case 2: one or more LINKs
    if (IsType $tok 'LINK') {
        $links = @()
        while (IsType (Get-Token $Tokens $i) 'LINK') {
            $links += (Get-Token $Tokens $i).Content
            $i++
        }
        return [pscustomobject]@{
            Success   = $true
            NextIndex = $i
            Def       = [pscustomobject]@{ Text=$null; Links=$links; Word=$null }
            Diagnostics = $diag
        }
    }

    # Case 3: CEBWORD
    if (IsType $tok 'CEBWORD') {
        $word = $tok.Content; $i++
        return [pscustomobject]@{
            Success   = $true
            NextIndex = $i
            Def       = [pscustomobject]@{ Text=$null; Links=@(); Word=$word }
            Diagnostics = $diag
        }
    }

    # Otherwise fail
    [pscustomobject]@{
        Success     = $false
        NextIndex   = $i
        Def         = $null
        Diagnostics = $diag + [pscustomobject]@{ Index=$i; Message="DEF: unexpected $($tok.Type)"; Token=$tok }
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
      NUMDEF ::= NUMBER DEFEX
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

    # collect CLASS*
    $classes = @()
    while (IsType (Get-Token $Tokens $i) 'CLASS') {
        $classes += (Get-Token $Tokens $i).Content
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
            Classes     = $classes
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
      WORDDEF ::= CEBWORD ( WTDEF+ | [DEFEX] NUMDEF+ | DEFEX )
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

    # Branch 1: WTDEF+
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

    # Branch 2a: NUMDEF+ (no leading DEFEX)
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

    # Branch 2b: optional leading DEFEX, then NUMDEF+ (if present)
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
                    Word             = $headTok.Content
                    DefExLead    = $defexLead.DefEx
                    NumberedDefs = $numdefs
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
      ROW ::= WORDDEF+
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

# iterates through the list of tokens and for each text token we process more specific tokens where found
# we usually start with a single text token per row
function Tokenize {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $token
    )
    process {
        # notes:
        # - corr must be processed before splitting words, since it is usally inside of the word block
        # - split links must be processed before cebuano phrases because of some bad formatting (they use <i lang="ceb"> as a way to make the word "see" italic, e.g. in "see otherword")
        $token | Strip-Corr | Split-Classes | Split-Cebuano-Words | Split-Types | Split-Nums | Split-Links | Split-Cebuano-Phrases | Strip-Punct
    }
}

# main
$paragraphs = $inxml | Split-Paragraphs

if ($Limit) {
    $paragraphs = $paragraphs | Select-Object -First $Limit
}

# basic tokenization saved to file for review
$paragraphs | foreach {
    # emit the tokens
    $_.tokens
    # emit a token indicating the end of a row
    [PSCustomObject]@{
        Type="ROWEND";
        Content=""
    }
} | Tokenize | Export-Csv -Encoding utf8 -NoTypeInformation -Path "tokenlist.csv"

$parsed = $paragraphs |
    ForEach-Object {
        # Keep your token normalization passes
        $_.Tokens = ($_.Tokens | Tokenize)

        # Parse the normalized token array into a structured tree
        $res = Parse-Row -Tokens $_.Tokens

        # Attach parse results to the row (non-destructive: adds properties)
        $_ | Add-Member -NotePropertyName WordDef           -NotePropertyValue $res.WordDef      -Force
        $_ | Add-Member -NotePropertyName ParseOk           -NotePropertyValue $res.Success      -Force
        $_ | Add-Member -NotePropertyName ParseNextIndex    -NotePropertyValue $res.NextIndex    -Force
        $_ | Add-Member -NotePropertyName ParseDiagnostics  -NotePropertyValue $res.Diagnostics  -Force

        $_  # emit the updated object to the pipeline
    }

$successfuls = $parsed | Where-Object { $_.ParseOk }
$faileds = $parsed | Where-Object { -not $_.ParseOk }

# Finally, write the whole set to JSON
$faileds |
    ConvertTo-Json -Depth 100 |
    Set-Content -Encoding UTF8 -Path "failed-parse.json"

# $successfuls.WordDef |
$successfuls |
    ConvertTo-Json -Depth 100 |
    Set-Content -Encoding UTF8 -Path "successful-parse.json"
