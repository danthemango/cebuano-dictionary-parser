# Utility function to convert multiple whitespace to single space
function reduceWS($text) {
    return ($text -replace "\s+", " ").Trim()
}

# strip pagenums from content
# <span class="pagenum">[<a id="xd20e22720" href="#xd20e22720">40</a>]</span>
function Remove-PageNums {
    param (
        [Parameter(Mandatory = $true)]
        [string]$content
    )

    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    return [regex]::Replace($content, '<span[^>]*class="pagenum"[^>]*>.*?</span>', '', $opts)
}

# look for paragraphs inside of each letter div
function Split-Paragraphs {
    param (
        [Parameter(ValueFromPipeline = $true)]
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
                        Type    = "TEXT"
                        Content = $content
                    }

                    [PSCustomObject]@{
                        Letter = $letter
                        Tokens = @($contentToken)
                        Raw    = $content
                    }
                }
            }
        }
    }
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
            [PSCustomObject]@{
                Type    = "TEXT"
                Content = reduceWS($splits[0])
            }
        }

        # Alternating: captured group (the match), then content after it
        for ($i = 1; $i -lt $splits.Count; $i += 2) {
            # Output the matched token (e.g., NUMBER)
            [PSCustomObject]@{
                Type    = $TokenType
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
        $Token | Split-TokensByPattern -pattern "<b>(\d+[a-z]?(?:,\s*\d+[a-z]?)*?)</b>" -tokenType "NUMBER"
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
function Split-Cebuano-Words {
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
# <i lang=""ceb"">Dakúa uy!</i>
function Split-Cebuano-Phrases {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        $Token | Split-TokensByPattern -pattern '<i lang="ceb">(.*?)</i>' -tokenType "CEBPHRASE"
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
function Split-Links {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        if ($Token.Type -ne "TEXT") { $Token; return }

        $content = $Token.Content
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline

        # capture the entire link block, including optional "see", "short for", or "=" at the beginning, and optional wordtype and numbers at the end, and optional parentheses around the whole thing, and an optional period at the end.
        $pattern = "[(]?(= |short for |<i lang=""ceb"">see</i>|)?<span class=""sc"" lang=""ceb"">(<a href=""#.*?"">)?(?<name>.*?)(</a>)?</span>(, )?(<i lang=""ceb"">(?<wordtype>[avn])</i>)?(<b lang=""ceb"">(?<numbers>[0-9, ]+)</b>)?[)]?\."

        $mymatches = [regex]::Matches($content, $pattern, $opts)
        if ($mymatches.Count -eq 0) { $Token; return }

        $pos = 0

        foreach ($m in $mymatches) {
            # Text before this match
            $beforeText = $content.Substring($pos, $m.Index - $pos)
            $beforeText = reduceWS($beforeText)
            if ($beforeText -ne "") {

                if ($beforeText -ne "") {
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
            $wt = $m.Groups['wordtype'].Value
            $nums = $m.Groups['numbers'].Value

            if ($wt -or $nums) { $linkText += ":" }
            if ($wt)   { $linkText += " $wt" }
            if ($nums) { $linkText += " $nums" }

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

# remove corr elements, leaving the text contents if there are any non-numbers
# <span class="corr" id="xd20e4931" title="Source: kunsididirasiyun">kunsidirasiyun</span>
# <span class="corr" id="xd20e5140" title="Not in source"><sub>1</sub></span>
function Split-RemoveCorr {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Token
    )
    process {
        # If not a TEXT token, pass through unchanged
        if ($Token.Type -ne "TEXT") {
            $Token
            return
        }

        $content = $Token.Content
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline

        # Pattern: <span class="corr" ...>...</span>
        $pattern = '<span[^>]*class="corr"[^>]*>.*?</span>'
        $splits = [regex]::Split($content, $pattern)
        $mymatches = [regex]::Matches($content, $pattern, $opts)
        # If no matches, return original token
        if ($mymatches.Count -eq 0) {
            $Token
            return
        }

        # if there are any matches, remove the span (and sub) tags from the text but leave the content in-place
        $newContent = ""
        for ($i = 0; $i -lt $mymatches.Count; $i++) {
            $newContent += $splits[$i]

            $spanMatch = $mymatches[$i].Value
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
# TODO delete if never used
# function Strip-Punct {
#     param (
#         [Parameter(ValueFromPipeline = $true)]
#         $Token
#     )
#     process {
#         # If not a TEXT token, pass through unchanged
#         if ($Token.Type -ne "TEXT") {
#             $Token
#             return
#         }

#         $content = $Token.Content
#         # If content is only punctuation or whitespace, skip it
#         if ($content -match '^[\s\.,;:!\?\-()"\'']*$') {
#             return
#         }

#         # Otherwise, emit the token unchanged
#         $Token
#     }
# }

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
        $Token | Split-Classes | Split-Nums | Split-Links | Split-Cebuano-Words | Split-Types | Split-Cebuano-Phrases
    }
}
