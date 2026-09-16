# Utility function to convert multiple whitespace to single space
function reduceWS {
    param (
        [string]$Content
    )
    [string] $NewContent = $Content.Trim() -replace "\s+", " "
    Assert-ValidXMLContent -NewContent $NewContent -OldContent $Content
    return ($NewContent)
}

function Split-TokensByPattern {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token,

        [Parameter(Mandatory = $true)]
        [string]$pattern,

        [Parameter(Mandatory = $true)]
        [string]$TokenType
    )
    process {
        # If not a TEXT token, pass through unchanged
        if ($Token.Type -ne "TEXT") {
            $Token
            return
        }

        $content = $Token.Content
        $splits = [regex]::Split($content, $pattern)

        # If no matches (only one part after split), return original token
        if ($splits.Count -le 1) {
            $Token
            return
        }

        # Output content before first match
        if ($splits[0].Trim() -ne "") {
            Assert-ValidXMLContent -NewContent $splits[0] -OldContent $Content
            [PSCustomObject]@{
                Type    = "TEXT"
                Content = reduceWS -Content $splits[0]
            }
        }

        # Alternating: captured group (the match), then content after it
        for ($i = 1; $i -lt $splits.Count; $i += 2) {
            # Output the matched token (e.g., NUMBER)
            Assert-ValidXMLContent -NewContent $splits[$i] -OldContent $Content
            [PSCustomObject]@{
                Type    = $TokenType
                Content = $splits[$i]
            }

            # Output content after this match
            $afterMatch = if ($i + 1 -lt $splits.Count) { $splits[$i + 1] } else { "" }
            if ($afterMatch.Trim() -ne "") {
                Assert-ValidXMLContent -NewContent $afterMatch -OldContent $Content
                [PSCustomObject]@{
                    Type    = "TEXT"
                    Content = reduceWS -Content $afterMatch
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Parses definition numbers from text tokens.
.DESCRIPTION
    parses a def number, e.g. <b>1</b>, <b>2</b>, <b>2a</b>
    or a comma-separated list of def numbers, e.g. <b>1, 2a, 3</b>
    accept as input an array of tokens, and for each text token
    return the number tokens and text tokens for all text found between them
#>
function Split-Nums {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        # fix <b lang="ceb">b1</b> and the like
        # I shouldn't have to do this but it's an obvious mistake made by the author
        $Token.Content = [regex]::Replace($Token.Content, '<b lang="ceb">(?<num>[a-z]?\d)</b>', '<b>${num}</b>')
        $Token.Content = [regex]::Replace($Token.Content, '<b lang="ceb">(?<num>\d[a-z]?)</b>', '<b>${num}</b>')

        # accept 1 to 3 digits of numbers and lowercase letters, and possibly with comma separated numbers
        $Token | Split-TokensByPattern -pattern "<b>([a-z0-9]{1,3}(?:,\s*[a-z0-9]{1,3})*?)</b>" -tokenType "NUMBER" | Assert-ValidXML
    }
}

# parse word types / parts of speech
# e.g. nouns (<i>n</i>), verbs (<i>v</i>), adjectives (<i>a</i>), etc.
function Split-Types {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        $Token | Split-TokensByPattern -pattern "<i[^>]*>([anv])</i>" -tokenType "WORDTYPE"
    }
}

# find other words that are included
# they may be separate conjugations listed with their own definitions (including definition types and numbers)
# other words, variations, conjugations, affixes
# <b lang="ceb">adtuúnun, aladtúun</b>
function Split-CebuanoWords {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        $pattern1 = "<b lang=""ceb"">\s*(.*?)\s*</b>"
        # the id is likely used to be the target of the internal links, not sure if that information can be used later.
        $pattern2 = "<b id=""[^""]+"" lang=""ceb"">\s*(.*?)\s*</b>"

        $Token | Split-TokensByPattern -pattern $pattern1 -tokenType "CEBWORD" | Split-TokensByPattern -pattern $pattern2 -tokenType "CEBWORD"
    }
}

# find cebuano phrases
# e.g.:
# <i lang="ceb">Dakúa uy!</i>
# <i lang="ceb">Abáhu (báhu) <span class="corr" id="xd20e4931" title="Source: kunsididirasiyun">kunsidirasiyun</span> ku sa ákung bána,</i> I am bound by my husband’’s decisions.
# <i lang="ceb">Lagmit hiligsan ang bátà kay nag-abay sa tartanilya,</i>
function Split-CebuanoPhrases {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        # note: this regex uses the negative lookahead: (?:(?!</i>).)*?
        # it's the 0 or more lazy quantifier with non-capturing group containing negative lookahead </i>
        # meaning: "capture any text as long as it's not </i>
        $Token | Split-TokensByPattern -pattern '^\s*<i lang="ceb">((?:(?!</i>).)*?[,!?\.])</i>' -tokenType "CEBPHRASE" | Split-TokensByPattern -pattern '(?<=[.!?]\)?\]?)\s*<i lang="ceb">((?:(?!</i>).)*?[,!?\.])</i>' -tokenType "CEBPHRASE"
    }
}

# there are also latin words marked, such as:
# <b lang="la"><i>Musa textilis</i></b>.
# <b lang="la"><i>Balamcanda chinensis</i></b>.
# <b lang="la"><i>Eurycles amboinensis</i></b>.
# <b lang="la"><i>Persea sp</i></b>.
# but only a few, and usually are part of a definition, so I'll leave them be

# find other words that are being linked to
# the links are in a span with class "sc", and may or may not be in an <a> (which may be discarded)
# I'd like to add a new field "links", which is a semicolon-separated list of words that are linked to this one
# removing the "=", the "short for", and the "see" words before and the optional dot at the end.
# e.g.:
# = <span class="sc" lang="ceb"><a href="#balbal">balbal</a></span>.
# short for <span class="sc" lang="ceb"><a href="#niadtu">niadtu</a></span>.
# <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>.
# = <span class="sc" lang="ceb"><a href="#abir">abir</a></span>.
# = <span class="sc" lang="ceb"><a href="#abir">abir</a></span><b lang="ceb">1, 2</b>.
# = <span class="sc" lang="ceb"><a href="#abaxga">abága</a></span>, <i lang="ceb">v</i>.
# <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>, <i lang="ceb">n</i><b lang="ceb">4</b>.
# (<i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>, <i lang="ceb">n</i><b lang="ceb">4</b>).
# = <span class="sc" lang="ceb">tangdayan</span>.
# = <span class="sc" lang="ceb"><a href="#tangdiq">tangdì</a></span>, <i lang="ceb">v1.</i>
# = <span class="sc" lang="ceb"><a href="#abud">abud</a></span>, <i lang="ceb">n</i> 2.
# = <span class="sc" lang="ceb"><a href="#kuxtil">kútil</a></span>, <i lang="ceb">n</i>, <i lang="ceb">v1.</i>
# <span class="sc" lang="ceb"><a href="#xxabubhu"><span class="corr" id="xd20e7109" title="Not in source">*</span>abubhu</a></span>.
function Split-Links {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        # exception for 2995
        $Token.Content = [regex]::Replace($Token.Content, '<span class="sc" lang="ceb">b.o</span>', 'b.o')

        # capture the entire link block, including optional "see", "short for", or "=" at the beginning, and optional wordtype and numbers at the end, and optional parentheses around the whole thing, and an optional period at the end.
        # see https://regex101.com/r/791KzX/1
        $pattern = '[(]?(= |short for |<i lang="ceb">see</i>|)? *<span class="sc" lang="ceb">(<a href="#.*?">)?(?<name>.*?)(</a>)?</span>((, )?(<i lang="ceb">(?<wordtype>[avn])</i>)?(<b lang="ceb">(?<numbers>[0-9, ]+)</b>)?[)]?(<i lang="(ceb|cebword)">(?<numbers>.*?\.?)\.?</i>| ?(?<numbers>\d)?\.))*'

        if ($Token.Type -ne "TEXT") {
            $Token
            return
        }

        [string]$Content = $Token.Content

        $mymatches = [regex]::Matches($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($mymatches.Count -eq 0) { $Token; return }

        $pos = 0

        foreach ($m in $mymatches) {
            # Text before this match
            $beforeText = $content.Substring($pos, $m.Index - $pos)
            $beforeText = reduceWS -Content $beforeText
            if ($beforeText -ne "") {

                if ($beforeText -ne "") {
                    Assert-ValidXMLContent -NewContent $beforeText -OldContent $Content
                    [PSCustomObject]@{
                        Type    = "TEXT"
                        Content = $beforeText
                    }
                }
            }

            # $spanMatch = $m.Groups['span'].Value
            # the name of the link is in the "name" group
            $linkText = $m.Groups['name'].Value
            # throw if linkText is empty, since that means our regex is wrong
            if ($linkText -eq "") {
                throw "Link text is empty for match: $($m.Value)"
            }
            # add the wordtype and numbers if they exist
            # $wt = $m.Groups['wordtype'].Value
            $wt = ($m.Groups['wordtype'].Captures | ForEach-Object Value) -join ' '
            $nums = ($m.Groups['numbers'].Captures | ForEach-Object Value) -join ' '

            if ($wt -or $nums) { $linkText += ":" }
            if ($wt)   { $linkText += " $wt" }
            if ($nums) { $linkText += " $nums" }

            Assert-ValidXMLContent -NewContent $linkText -OldContent $Content
            [PSCustomObject]@{
                Type    = "LINK"
                Content = $linkText
            }

            # Advance position to end of entire match (including the period we consumed)
            $pos = $m.Index + $m.Length
        }

        # emit the remaining text of token
        $tail = $content.Substring($pos)
        if ($tail.Trim() -ne "") {
            $afterText = $tail
            $afterText = reduceWS -Content $afterText

            if ($afterText -ne "") {
                Assert-ValidXMLContent -NewContent $afterText -OldContent $Content
                [PSCustomObject]@{
                    Type    = "TEXT"
                    Content = $afterText
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
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        $pattern = '<span class="rm">(.*?)</span>'
        $Token | Split-TokensByPattern -pattern $pattern -tokenType "CLASS"
    }
}

<#
.SYNOPSIS
    find and replace elements which appear like a cebphrase, but don't have a comma at the end of text inside the <i>, as expected.
.DESCRIPTION
    the problem is that these elements are put in an <i> element like a cebuano phrase, but are usually just one-off examples of a cebuano word in a definition (or a gloss?)
.NOTES
    this must happen after Split-Links, since they tagged the word "See" as if it is a cebuano phrase incorrectly.
#>
# examples:
# be infested with <i lang="ceb">abungaw.</i>
function Update-ChangeCebWord {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        if ($Token.Type -ne "TEXT") { $Token; return }

        # find italic sections that are actually just explanations
        # `<i lang=""cebword"">particle with a statement or exclamation:</i> [so-and-so] is different than it should be.`
        # anything with a colon:
        $Token.Content = [regex]::Replace($Token.Content, '<i lang="ceb">(?<content>(?:.)*?:)</i>', '<i>${content}</i>')
        # if the some keywords appear, I will assume it's a mistagged section
        $Token.Content = [regex]::Replace($Token.Content, '<i lang="ceb">(?<content>[^<]*?(word|past|statement|particle|condition|future|existential|with|interrogative|phrase|subject|addition|compare|quotation|s\.t\.|s\.o|s\.w\.|k\.o\.|lit\.|voc\.|noun|pronoun|adj\.)[^<]*?)</i>', '<i>${content}</i>')

        # if there is no comma at the end inside of the tags,
        # replace lang="ceb" with lang="cebword"
        $Token.Content = [regex]::Replace($Token.Content, '<i lang="ceb">(?<content>(?:(?!</i>).)*?[^,!?\.])</i>', '<i lang="cebword">${content}</i>')
        $Token.Content = [regex]::Replace($Token.Content, '<i lang="ceb">(?<content>(?:(?!</i>)[^\s])*?)</i>', '<i lang="cebword">${content}</i>')
        $Token | Assert-ValidXML
    }
}

<#
.DESCRIPTION
    remove all <span class="corr"> elements, outputting children
#>
function Update-Corr {
    param(
        [Parameter(ValueFromPipeline)]
        $Token
    )

    process {
        if ($Token.Type -ne 'TEXT') {
            $Token
            return
        }

        $xml = [xml]("<root>$($Token.Content)</root>")

        $nodes = $xml.SelectNodes("//*[@class='corr']")

        # Copy to array because we're modifying the document
        @($nodes) | ForEach-Object {
            $node   = $_
            $parent = $node.ParentNode

            # Insert children before the wrapper node
            while ($node.FirstChild) {
                $parent.InsertBefore($node.FirstChild, $node) | Out-Null
            }

            # Remove the now-empty wrapper
            $parent.RemoveChild($node) | Out-Null
        }

        $Token.Content = ($xml.DocumentElement.InnerXml)

        $Token | Assert-ValidXML
    }
}

function Update-ShortForm {
    param(
        [Parameter(ValueFromPipeline)]
        $Token
    )

    process {
        if ($Token.Type -ne 'TEXT') {
            $Token
            return
        }

        if ($Token.Content -Like "*Short Form*") {
            throw "'Short Form' tokenization not implementd yet."
        }

        # if ($Token.Content -Like "*in set phrases*") {
        #     throw "'in set phrases' tokenization not implementd yet."
        # }

        $Token
        return
    }
}

function Assert-ValidXMLContent {
    param (
        [string]$OldContent,
        [string]$NewContent
    )

    if (-not (IsValidXML -Content $NewContent)) {
        throw "Invalid XML content: $NewContent original content: $OldContent"
    }
}

function IsValidXML {
    param (
        [string]$Content
    )

    # return if content is empty
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $True
    }

    try {
        [xml]$xml = "<root>$Content</root>"
        return $null -ne $xml.root
    } catch {
        return $False
    }
    return $True
}

<#
.SYNOPSIS
    Throws an exception if there is invalid xml in the content

#>
function Assert-ValidXML {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        $content = $Token.Content
        if (-not (IsValidXML -Content $content)) {
            throw "Invalid XML content: $content"
        }
        $Token
    }
}

<#
.DESCRIPTION
    throws an exception on a few known limitations
#>
function Assert-Implemented {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        $content = $Token.Content
        # throw exceptions on specific keywords: "see also", "short for", "cf."
        # case insensitive

        if ($content -match "(?i)see also") {
            throw "Not implemented: see also: $content"
        }
        if ($content -match "(?i)short for") {
            throw "Not implemented: short for: $content"
        }
        if ($content -match "(?i)cf\.") {
            throw "Not implemented: cf.: $content"
        }
        $Token
    }
}

function Repair-Typos {
    param(
        [Parameter(ValueFromPipeline)]
        $Token
    )

    process {
        # noun and "a", marked as adjective but probably just a typo
        $Token.Content = $Token.Content -replace '<i>[anv]</i>\s*<i>a</i>', '<i>n</i> a'
        # a mislabelled number (capture)
        $Token.Content = $Token.Content -replace '<i lang="ceb">(?<num>(?=[a-z0-9]*\d)[a-z0-9]+)</i>', '<b>${num}</b>'
        # strip link formatting from acronyms
        $Token.Content = $Token.Content -replace '<span class="sc" lang="ceb">(?<accr>(\w\.)+\w?)</span>', '${accr}'

        $Token
    }
}

# iterates through the list of tokens and for each text token we process more specific tokens where found
# we usually start with a single text token per row
function Tokenize {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        # notes:
        # - corr must be processed before splitting words, since it is usally inside of the word block
        # - split links must be processed before cebuano phrases because of some bad formatting (they use <i lang="ceb"> as a way to make the word "see" italic, e.g. in "see otherword")
        # I think each step should have valid XML, so we can assert valid XML after each step
        $Token | Assert-ValidXML | Repair-Typos | Update-ShortForm | Update-Corr | Split-Nums | Split-Links | Split-CebuanoWords | Split-Classes | Split-Types | Update-ChangeCebWord | Split-CebuanoPhrases | Assert-ValidXML | Assert-Implemented
    }
}
