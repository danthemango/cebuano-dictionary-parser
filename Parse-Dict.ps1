# .EXAMPLE
# .\HTML-to-XML.ps1 | .\Parse-Dict.ps1 | Export-Csv .\cebuano-dictionary.csv

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

# e.g. nouns, verbs, adverbs
# looks for <i>n</i>, <i>v</i>, <i>a</i>, etc. (single-char)
# if none found set field "type" to "", else set "type" to the letter (n, v, a, etc.)
function Split-Types {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $item
    )
    process {
        $type = ""
        $content = $item.content

        # Fast path: regex over HTML fragment
        $m = [regex]::Match($content, '<i[^>]*>\s*([A-Za-z])\s*</i>')
        if ($m.Success) {
            $type = $m.Groups[1].Value.ToLower()
            # Remove the first match from content
            $content = [regex]::Replace($content, '<i[^>]*>\s*[A-Za-z]\s*</i>', '', 1)
        }

        # if class found, use it, else default to what was passed in
        # parse class from content, if any
        $newClass, $content = Parse-ClassContent $content

        if ($newClass) {
            $item.class = $newClass
        }

        $item.type = $type
        $item.content = reduceWS($content)
        $item
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
        $links = @()

        # regex to find spans with class "sc"
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
        $matches = [regex]::Matches($content, '<span[^>]*class="sc"[^>]*>(.*?)</span>', $opts)

        foreach ($match in $matches) {
            $innerHtml = $match.Groups[1].Value

            # extract the linked word, either from <a> or directly
            $linkMatch = [regex]::Match($innerHtml, '<a[^>]*>(.*?)</a>')
            if ($linkMatch.Success) {
                $links += reduceWS($linkMatch.Groups[1].Value)
            } else {
                $links += reduceWS($innerHtml)
            }
        }

        # remove the link spans from content
        # $cleanContent = [regex]::Replace($content, '=? ?<span[^>]*class="sc"[^>]*>.*?</span>\.?', '', $opts)
        # and remove <i lang="ceb">see</i> if found before the span
        $cleanContent = [regex]::Replace($content, '=? ?(<i[^>]*>\s*see\s*</i>\s*)?<span[^>]*class="sc"[^>]*>.*?</span>\.?', '', $opts)

        $item.links = ($links -join "; ")
        $item.content = reduceWS($cleanContent)
        $item
    }
}

# main
$inxml | Split-Words | Parse-Class | Split-Types | Split-Nums | Parse-Class | Parse-Links
