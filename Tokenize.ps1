# .EXAMPLE
# .\HTML-to-XML.ps1 | .\Tokenize.ps1 -Limit 100 | Export-Csv -Encoding utf8 -NoTypeInformation -Path "tokenlist.csv"
# .EXAMPLE
# $xml = .\HTML-to-XML.ps1
# $tokens = $xml | .\Tokenize.ps1 -Limit 100
# $tokens | Export-Csv -Encoding utf8 -NoTypeInformation -Path "tokenlist.csv"
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
$paragraphs | ForEach-Object {
    $_.tokens = $_.tokens | Tokenize
    $cebWords = $_.tokens | Where-Object Type -eq "CEBWORD"
    if ($cebWords.Count -eq 0) {
        $Word = ""
    } else {
        $Word = $cebWords[0].Content
    }

    $_.tokens | Add-Member -NotePropertyName "Word" -NotePropertyValue $Word -Force
    $_.tokens

    # $firstCebWord = ($cebWords | Select-Object -First 1).Content

    # # # add the word as column
    # # foreach ($token in $_.tokens) {
    # # }

    # # emit the tokens
    # $_.tokens
}
