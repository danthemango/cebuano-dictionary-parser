
param (
    [string]$inpath = ".\cebuano-dictionary.html",
    [string]$outpath = ".\cebuano_dictionary_parsed.csv"
)

$entries = @()

$html = Get-Content $inpath

[xml]$xml = $html
if (-not $xml) {
    throw "could not parse html"
}

# Utility function to convert multiple whitespace to single space
function reduceWS($text) {
    return ($text -replace "\s+", " ").Trim()
}

# Extract referenced words/links and remove them from the HTML fragment
function extractReferences($html) {
    $links = @()
    if (-not $html) { return [PSCustomObject]@{ links = $null; html = $html } }

    $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline

    # Patterns: leading '=' then a .sc span, or an <i>see</i> then a .sc span
    $patternEqual = '(?:=)\s*(<span[^>]*class="sc"[^>]*>.*?</span>)'
    $patternSee = '<i[^>]*>\s*see\s*</i>\s*(<span[^>]*class="sc"[^>]*>.*?</span>)'

    foreach ($m in [regex]::Matches($html, $patternEqual, $opts)) {
        $span = $m.Groups[1].Value
        $text = ($span -replace '<[^>]*>', '') -replace '\s+', ' '
        $text = $text.Trim()
        if ($text) { $links += $text }
    }
    foreach ($m in [regex]::Matches($html, $patternSee, $opts)) {
        $span = $m.Groups[1].Value
        $text = ($span -replace '<[^>]*>', '') -replace '\s+', ' '
        $text = $text.Trim()
        if ($text) { $links += $text }
    }

    # Remove the matched fragments from the html
    $clean = $html -replace $patternEqual, '' -replace $patternSee, ''

    return [PSCustomObject]@{
        links = if ($links.Count -gt 0) { ($links | ForEach-Object { $_.Trim() }) -join ';' } else { $null }
        html  = $clean
    }
}

function cleanContent($text) {
    $result = reduceWS($text) -replace "<[^>]*>", ""
    # strip out everything if there is no text except punctuation or whitespace:
    if ($result -match "^[\p{P}\s]*$") {
        return ""
    }
    return $result
}

# Parse content by word type and numbered definitions
function parseWordTypeContent($content, $typeChar) {
    # find and remove all page number links
    # e.g. <span class="pagenum">[<a id="xd20e6352" href="#xd20e6352">5</a>]</span>
    # These can span multiple lines, so use Singleline flag and . to match newlines
    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $content = [regex]::Replace($content, '<span[^>]*class="pagenum"[^>]*>.*?</span>', '', $opts)

    # Parse numbered definitions using regex: <b>(\d+)</b>
    $defSplits = [regex]::Split($content, "<b>(\d+)</b>")

    $typeEntry = @{
        type        = $typeChar
        definitions = @()
    }

    # Helper function to extract class from definition
    function extractClass($defContent) {
        $classMatch = [regex]::Match($defContent, '<span class="rm">\[([^\]]+)\]</span>')
        if ($classMatch.Success) {
            return reduceWS($classMatch.Groups[1].Value)
        }
        return $null
    }

    # First element is text before any numbered definition (general definition for this type)
    if ($defSplits[0].Trim() -ne "") {
        $refs = extractReferences $defSplits[0]
        $contentWithoutRefs = $refs.html

        # remove class span before stripping tags
        $contentWithoutClass = $contentWithoutRefs -replace '<span class="rm">\[[^\]]+\]</span>', ""
        $cleanContent = cleanContent($contentWithoutClass)

        $typeEntry.definitions += @{
            number  = $null
            class   = extractClass($defSplits[0])
            links   = $refs.links
            content = $cleanContent
        }
    }

    # Then alternating: definition number, definition content
    for ($j = 1; $j -lt $defSplits.Count; $j += 2) {
        $defNum = $defSplits[$j]
        $defContent = if ($j + 1 -lt $defSplits.Count) { $defSplits[$j + 1] } else { "" }

        $refs = extractReferences $defContent
        $contentWithoutRefs = $refs.html
        $contentWithoutClass = $contentWithoutRefs -replace '<span class="rm">\[[^\]]+\]</span>', ""
        $cleanContent = cleanContent($contentWithoutClass)

        $typeEntry.definitions += @{
            number  = $defNum
            class   = extractClass($defContent)
            links   = $refs.links
            content = $cleanContent
        }
    }

    return $typeEntry
}

$wordEntries = @()
foreach ($section in Select-Xml -Xml $xml -XPath "//div[@class='div1 letter']") {
    foreach ($node in $section.Node) {
        # strip the text 'letter.' from id:
        $letter = $node.id -replace "^letter\.", ""

        $divBodies = $node.ChildNodes | Where-Object class -eq divBody
        foreach ($divBody in $divBodies) {
            foreach ($para in $divBody.p) {
                # notes:
                # - words may have multiple word types, specified by:
                #   - <i>n</i> (noun)
                #   - <i>v</i> (verb)
                #   - <i>a</i> (adverb)
                # - every word type may also have numbered definitions, separated with integers like:
                #   - <b>1</b>
                #   - <b>2</b>
                # - most definitions start with a class, like:
                #   - <span class="rm">[B2]</span>
                # - many words also have conjugations listed in the same <p>, and may have types and definitions, e.g. under <b lang="ceb">baíid</b>
                #   - <b lang="ceb">— ug náwung</b> (baíidug náwung)
                # - most definitions also have example phrases and their corresponding translation, with untranslateable cebuano words marked with lang="ceb"
                # - a definition may also have a link to a different word, e.g.:
                #   - = <span class=""sc"" lang=""ceb""><a href=""#abugaxdu"" class=""pginternal"">abugádu</a></span>

                # so organize as word > (later: conjugations > ) word type > number > definition + phrases

                # parse the definition and example phrases later, just capture the whole thing if there are no word types or numbers

                # note: word types must only have one char inside of them
                # get the node content after the word, and then split by word type (if any found):

                $cebs = $para.SelectNodes(".//b[@lang='ceb']")
                $word = reduceWS($cebs[0].InnerText)

                # Get all content after the word node by collecting sibling nodes
                $wordNode = $cebs[0]
                $contentNodes = @()
                $node = $wordNode.NextSibling
                while ($node) {
                    $contentNodes += $node
                    $node = $node.NextSibling
                }
                $contentAfterWord = ($contentNodes | ForEach-Object {
                    if ($_.NodeType -eq "Text") { $_.Value } else { $_.OuterXml }
                }) -join ""

                # Parse word types and definitions using regex on the content
                # Word types are in <i>X</i> where X is single char (n, v, a, etc.)
                $wordTypeSplits = [regex]::Split($contentAfterWord, "<i>(.)</i>")

                # Build structure: word > wordType > definitions
                $wordEntry = @{
                    letter = $letter
                    word  = $word
                    types = @()
                }

                # $wordTypeSplits[0] is content before first word type (treat as "unknown")
                # Then alternating: word type char, content for that type
                for ($i = 1; $i -lt $wordTypeSplits.Count; $i += 2) {
                    $typeChar = $wordTypeSplits[$i]
                    $typeContent = if ($i + 1 -lt $wordTypeSplits.Count) { $wordTypeSplits[$i + 1] } else { "" }
                    $wordEntry.types += parseWordTypeContent $typeContent $typeChar
                }

                # Handle content before first word type (empty type)
                if ($wordTypeSplits[0].Trim() -ne "") {
                    $wordEntry.types += parseWordTypeContent $wordTypeSplits[0] ""
                }

                $wordEntries += $wordEntry
            }
        }
    }
}

# pipe to csv with fields: letter, word, type, (later: class), number, content
$wordEntries | ForEach-Object {
    $wordEntry = $_
    $letter = $wordEntry.letter
    $word = $wordEntry.word
    foreach ($typeEntry in $wordEntry.types) {
        $typeChar = $typeEntry.type
        foreach ($def in $typeEntry.definitions) {
            [PSCustomObject]@{
                letter  = $letter
                word    = $word
                type    = $typeChar
                number  = $def.number
                class   = $def.class
                links   = $def.links
                content = $def.content
            }
        }
    }
} | Export-Csv -Path "$outpath" -NoTypeInformation -Encoding UTF8