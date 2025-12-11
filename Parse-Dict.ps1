# .EXAMPLE
# .\HTML-to-XML.ps1 | .\Parse-Dict.ps1 | Export-Csv .\cebuano-dictionary.csv

# after the word, there may be one or more types (e.g. <i>n</i>, <i>v</i>, <i>a</i>)
# then each type may have one or more numbered definitions
# and a definition may be a conjugation
# then after all numbered definitions there may be one or more conjugations
# which also may have zero or more types of its own
# and may also have zero or more numbered definitions
# there may be a conjugation that is part of a definition (e.g. after the word type or the word conjugation)

param (
    # accept input as xml object piped in, mandatory
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    [xml]$inxml = $null
)

# Utility function to convert multiple whitespace to single space
function reduceWS($text) {
    return ($text -replace "\s+", " ").Trim()
}

# strip the class of the definition and move it to the "class" field
# e.g.:
# <span class="rm">[A13; a12]</span>
function Parse-ClassContent {
    param (
        [Parameter(Mandatory=$false)]
        [string]$content
    )

    if ([string]::IsNullOrEmpty($content)) {
        return @($null, "")
    }

    # look for the first class in the definition
    # and return both the class content and the rest of the content with the tag removed:
    $classMatch = [regex]::Match($content, '^\s*<span[^>]*class="rm"[^>]*>\[([^\]]+)\]</span>')
    if ($classMatch.Success) {
        $class = reduceWS($classMatch.Groups[1].Value)
        $restContent = $content -replace '^\s*<span[^>]*class="rm"[^>]*>\[([^\]]+)\]</span>', ''
        @($class, (reduceWS $restContent))
    } else {
        @($null, (reduceWS $content))
    }
}

function Parse-Class {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $item
    )
    process {
        # if class found, set the field in the item, else leave it alone
        $class, $content = Parse-ClassContent $item.content
        if (-not $class) {
            $item
        } else {
            $item.class = $class
            $item.content = $content
            $item
        }
    }
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

function Split-Words {
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
                    $cebs = $para.SelectNodes(".//b[@lang='ceb']")
                    if (-not $cebs -or $cebs.Count -eq 0) { continue }

                    $word = $cebs[0].InnerText
                    # reduce whitespace
                    $word = reduceWS($word)

                    if ([string]::IsNullOrEmpty($word)) { continue }

                    # Get all content after the word node by collecting sibling nodes
                    $wordNode = $cebs[0]
                    $contentNodes = @()
                    $node = $wordNode.NextSibling
                    while ($node) {
                        $contentNodes += $node
                        $node = $node.NextSibling
                    }

                    $content = ($contentNodes | ForEach-Object {
                        if ($_.NodeType -eq "Text") { $_.Value } else { $_.OuterXml }
                    }) -join ""

                    # remove page numbers
                    $content = Remove-PageNums $content

                    # reduce whitespace
                    $content = reduceWS($content)

                    [PSCustomObject]@{
                        letter  = $letter
                        word    = $word
                        conj    = ""
                        class   = ""
                        type    = ""
                        number  = ""
                        links   = ""
                        content = $content
                    }
                }
            }
        }
    }
}

# split each entry by conjugation, e.g.
# <b lang=""ceb"">pakataga-</b>
# if there is any text prior to the conjugation (or none found), set conj = "" and leave content as is,
# else set conj to the conjugation found
function Split-Conjs {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $item
    )
    process {
        $content = $item.content

        # regex to find conjugation: <b lang="ceb">...</b>
        $conjMatch = [regex]::Match($content, '<b[^>]*lang="ceb"[^>]*>(.*?)</b>')

        if ($conjMatch.Success) {
            $conj = reduceWS($conjMatch.Groups[1].Value)
            # Remove the conjugation from content
            $content = [regex]::Replace($content, '<b[^>]*lang="ceb"[^>]*>.*?</b>', '', 1)

            $item.conj = $conj
            $item.content = reduceWS($content)
            $item
        } else {
            # no conjugation found
            $item.conj = ""
            $item.content = reduceWS($content)
            $item
        }
    }
}

# e.g. nouns, verbs, adverbs
# looks for <i>n</i>, <i>v</i>, <i>a</i>, etc. (single-char)
# if none found set field "type" to "", else set "type" to the letter (n, v, a, etc.)
function Split-Types {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $item
    )
    process {
        $content = $item.content
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
        $matches = [regex]::Matches($content, '<i[^>]*>\s*([A-Za-z])\s*</i>', $opts)

        if ($matches.Count -eq 0) {
            # no types found: keep item as-is
            $item.type = ""
            $item.content = reduceWS($content)
            $item
            return
        }

        # For each type match, emit one item where content is the text between this <i> and the next <i>
        for ($i = 0; $i -lt $matches.Count; $i++) {
            $m = $matches[$i]
            $typeChar = $m.Groups[1].Value.ToLower()

            $startAfter = $m.Index + $m.Length
            $nextIndex = if ($i + 1 -lt $matches.Count) { $matches[$i + 1].Index } else { $content.Length }
            $segment = ""
            if ($nextIndex -gt $startAfter) {
                $segment = $content.Substring($startAfter, $nextIndex - $startAfter)
            }

            $newItem = $item | Select-Object *
            $newItem.type = $typeChar
            $newItem.content = reduceWS($segment)
            $newItem
        }
    }
}

# split numbered defines
# split on numbers like <b>1</b>, <b>2</b>, etc.
# if none found set num to "", else set it
function Split-Nums {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $item
    )
    process {
        $content = $item.content

        # Split by numbered definitions using regex: <b>(\d+)</b>
        $defSplits = [regex]::Split($content, "<b>(\d+)</b>")

        # If no numbered definitions found, output single entry with num=""
        if ($defSplits.Count -le 1) {
            $item.number = ""
            $item.content = reduceWS($content)
            $item
        } else {
            # $defSplits[0] is content before first number (treat as num="")
            if ($defSplits[0].Trim() -ne "") {
                $item.number = ""
                $item.content = reduceWS($defSplits[0])
                $item
            }

            # Then alternating: number, content for that number
            for ($i = 1; $i -lt $defSplits.Count; $i += 2) {
                $num = $defSplits[$i]
                $defContent = if ($i + 1 -lt $defSplits.Count) { $defSplits[$i + 1] } else { "" }

                # Clone the item for each numbered definition
                $newItem = $item | Select-Object *
                $newItem.number = $num
                $newItem.content = reduceWS($defContent)
                $newItem
            }
        }
    }
}

# TODO parse the equal to links separately, since they are supposed to be perfectly equivalent

# parse links
# the links are in a span with class "sc", and may or may not be in an <a> (which may be discarded)
# I'd like to add a new field "links", which is a semicolon-separated list of words that are linked to this one
# removing the "=", the "short for", and the "see" words before and the optional dot at the end.
# e.g.:
# = <span class="sc" lang="ceb"><a href="#balbal">balbal</a></span>.
# short for <span class="sc" lang="ceb"><a href="#niadtu">niadtu</a></span>.
# <i lang="ceb">see</i><span class="sc" lang="ceb"><a href="#abay">abay</a></span>.
function Parse-Links {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $item
    )
    process {
        $content = $item.content
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
        $matches = [regex]::Matches($content, '<span[^>]*class="sc"[^>]*>(.*?)</span>', $opts)

        if ($matches.Count -eq 0) {
            # no links: preserve item, ensure links empty and normalized content
            $item.links = ""
            $item.content = reduceWS($content)
            $item
            return
        }

        # Emit the text before the first span (if any)
        $prevEnd = 0
        for ($i = 0; $i -lt $matches.Count; $i++) {
            $m = $matches[$i]
            $start = $m.Index

            # text before this match
            if ($start -gt $prevEnd) {
                $before = $content.Substring($prevEnd, $start - $prevEnd)
                if ($before.Trim() -ne "") {
                    $preItem = $item | Select-Object *
                    $preItem.links = ""
                    $preItem.content = reduceWS($before)
                    $preItem
                }
            }

            # extract the link text from the matched span
            $innerHtml = $m.Groups[1].Value
            $linkMatch = [regex]::Match($innerHtml, '<a[^>]*>(.*?)</a>')
            if ($linkMatch.Success) {
                $linkText = reduceWS($linkMatch.Groups[1].Value)
            } else {
                $linkText = reduceWS($innerHtml -replace '<[^>]*>', '')
            }

            # determine text between this span and the next span (or end)
            $nextStart = $m.Index + $m.Length
            $nextMatchStart = if ($i + 1 -lt $matches.Count) { $matches[$i + 1].Index } else { $content.Length }
            $between = ""
            if ($nextMatchStart -gt $nextStart) {
                $between = $content.Substring($nextStart, $nextMatchStart - $nextStart)
            }

            # emit an item for this link, with content equal to the following text segment
            $linkItem = $item | Select-Object *
            $linkItem.links = $linkText
            $linkItem.content = reduceWS($between)
            $linkItem

            $prevEnd = $nextStart
        }

        # if any trailing text after the last span, emit it
        if ($prevEnd -lt $content.Length) {
            $trail = $content.Substring($prevEnd)
            if ($trail.Trim() -ne "") {
                $trailItem = $item | Select-Object *
                $trailItem.links = ""
                $trailItem.content = reduceWS($trail)
                $trailItem
            }
        }
    }
}

# returns a type object if one found at the start of the content, e.g. for nouns: <i>n<i>
# and returns the rest of the content with it removed
function Parse-Type {
    param (
        [string]$content
    )

    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $pattern = '^\s*<i[^>]*>\s*([A-Za-z])\s*</i>\s*'
    $match = [regex]::Match($content, $pattern, $opts)
    if ($match.Success) {
        $matched = $match.Groups[1].Value
        $restContent = $content -replace $pattern, ''
        @($matched, (reduceWS $restContent))
    } else {
        @($null, ($content))
    }
}

# parses a def number, e.g. <b>1</b>, <b>2</b>, <b>2a</b>
function Parse-Num {
    param (
        [string]$content
    )

    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $pattern = '^\s*<b[^>]*>\s*(\d+[a-z]*)\s*</b>\s*'
    # $pattern = '^\s*<b[^>]*>\s*(\d+)*'
    $match = [regex]::Match($content, $pattern, $opts)
    if ($match.Success) {
        $matched = $match.Groups[1].Value.ToLower()
        $restContent = $content -replace $pattern, ''
        @($matched, (reduceWS $restContent))
    } else {
        @($null, ($content))
    }
}

function Tokenize-Content {
    param (
        [Parameter(Mandatory=$true)]
        [string]$html
    )

    $tokens = New-Object System.Collections.Generic.List[PSObject]
    if ([string]::IsNullOrEmpty($html)) { return $tokens }

    $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor `
            [System.Text.RegularExpressions.RegexOptions]::Singleline

    # Match order matters: conjugation (b with lang=ceb) first, then numbered <b>, then <i> types,
    # then class spans, sc link spans, other <b> tags, plain text, and generic tags.
    $pattern = '(?<conj><b[^>]*\blang=(?:"|''?)ceb(?:"|''?)[^>]*>.*?<\/b>)|' +
               '(?<num><b>\s*(\d+[a-z]?)\s*<\/b>)|' +
               '(?<type><i[^>]*>\s*([A-Za-z])\s*<\/i>)|' +
               '(?<class><span[^>]*class=(?:"|''?)rm(?:"|''?)[^>]*>\[[^\]]+\]<\/span>)|' +
               '(?<link><span[^>]*class=(?:"|''?)sc(?:"|''?)[^>]*>.*?<\/span>)|' +
               '(?<btag><b[^>]*>.*?<\/b>)|' +
               '(?<text>[^<]+)|(?<tag><[^>]+>)'

    $pos = 0
    while ($pos -lt $html.Length) {
        $m = [regex]::Match($html, $pattern, $opts, $pos)
        if (-not $m.Success) { break }

        $tokenType = $null
        if ($m.Groups['conj'].Success)   { $tokenType = 'CONJ' ; $raw = $m.Groups['conj'].Value }
        elseif ($m.Groups['num'].Success){ $tokenType = 'NUMBER'; $raw = $m.Groups['num'].Value }
        elseif ($m.Groups['type'].Success){ $tokenType = 'TYPE'; $raw = $m.Groups['type'].Value }
        elseif ($m.Groups['class'].Success){ $tokenType = 'CLASS'; $raw = $m.Groups['class'].Value }
        elseif ($m.Groups['link'].Success){ $tokenType = 'LINKSPAN'; $raw = $m.Groups['link'].Value }
        elseif ($m.Groups['btag'].Success){ $tokenType = 'BTAG'; $raw = $m.Groups['btag'].Value }
        elseif ($m.Groups['text'].Success){ $tokenType = 'TEXT'; $raw = $m.Groups['text'].Value }
        else { $tokenType = 'TAG'; $raw = $m.Value }

        # Cleaned/text value for convenience
        switch ($tokenType) {
            'CONJ' {
                $inner = [regex]::Match($raw, '<b[^>]*>(.*?)<\/b>', $opts).Groups[1].Value
                $text = ( ($inner) -replace '<[^>]*>', '' ) -replace '\s+', ' '
            }
            'NUMBER' {
                $num = [regex]::Match($raw, '\d+[a-z]?', $opts).Value
                $text = $num
            }
            'TYPE' {
                $t = [regex]::Match($raw, '([A-Za-z])', $opts).Groups[1].Value
                $text = $t.ToLower()
            }
            'CLASS' {
                $c = [regex]::Match($raw, '\[([^\]]+)\]', $opts).Groups[1].Value
                $text = $c
            }
            'LINKSPAN' {
                $a = [regex]::Match($raw, '<a[^>]*>(.*?)<\/a>', $opts)
                if ($a.Success) { $text = ($a.Groups[1].Value -replace '<[^>]*>', '') -replace '\s+', ' ' }
                else { $text = ($raw -replace '<[^>]*>', '') -replace '\s+', ' ' }
            }
            'BTAG' { $text = ($raw -replace '<[^>]*>', '') -replace '\s+', ' ' }
            'TEXT' { $text = $raw -replace '\s+', ' ' }
            default { $text = $raw -replace '<[^>]*>', '' -replace '\s+', ' ' }
        }

        $tokens.Add([PSCustomObject]@{
            Type  = $tokenType
            Raw   = $raw
            Text  = ($text.Trim())
            Index = $m.Index
            Length = $m.Length
        })

        $pos = $m.Index + $m.Length
    }

    return ,$tokens
}

# main
# $inxml | Split-Words | foreach { $_.content } # | foreach { Tokenize-Content $_.content }

# test parsing type
$inxml | Split-Words | foreach { $_.content } | foreach {
    $type, $rest = Parse-Num $_
    [PSCustomObject]@{
        type = $type
        rest = $rest
    }
}

# | Split-Types | Split-Nums | Split-Conjs | Parse-Links
