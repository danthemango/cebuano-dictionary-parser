
$entries = @()

$html = Get-Content '.\pg40074-images.html'
[xml]$xml = $html
if (-not $xml) {
    throw "could not parse html"
}

# Utility function to convert multiple whitespace to single space
function reduceWS($text) {
    return ($text -replace "\s+", " ").Trim()
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

                    # Now parse numbered definitions within $typeContent using regex: <b>(\d+)</b>
                    $defSplits = [regex]::Split($typeContent, "<b>(\d+)</b>")

                    $typeEntry = @{
                        type        = $typeChar
                        definitions = @()
                    }

                    # First element is text before any numbered definition (general definition for this type)
                    if ($defSplits[0].Trim() -ne "") {
                        $typeEntry.definitions += @{
                            number  = $null
                            content = (reduceWS($defSplits[0]) -replace "<[^>]*>", "")  # Strip HTML tags
                        }
                    }

                    # Then alternating: definition number, definition content
                    for ($j = 1; $j -lt $defSplits.Count; $j += 2) {
                        $defNum = $defSplits[$j]
                        $defContent = if ($j + 1 -lt $defSplits.Count) { $defSplits[$j + 1] } else { "" }

                        $typeEntry.definitions += @{
                            number  = $defNum
                            content = (reduceWS($defContent) -replace "<[^>]*>", "")  # Strip HTML tags
                        }
                    }

                    $wordEntry.types += $typeEntry
                }

                # Handle content before first word type (unknown type)
                if ($wordTypeSplits[0].Trim() -ne "") {
                    $defSplits = [regex]::Split($wordTypeSplits[0], "<b>(\d+)</b>")
                    $typeEntry = @{
                        type        = ""
                        definitions = @()
                    }

                    # First element is text before any numbered definition
                    if ($defSplits[0].Trim() -ne "") {
                        $typeEntry.definitions += @{
                            number  = $null
                            content = (reduceWS($defSplits[0]) -replace "<[^>]*>", "")
                        }
                    }

                    # Then alternating: definition number, definition content
                    for ($j = 1; $j -lt $defSplits.Count; $j += 2) {
                        $defNum = $defSplits[$j]
                        $defContent = if ($j + 1 -lt $defSplits.Count) { $defSplits[$j + 1] } else { "" }

                        $typeEntry.definitions += @{
                            number  = $defNum
                            content = (reduceWS($defContent) -replace "<[^>]*>", "")
                        }
                    }

                    $wordEntry.types += $typeEntry
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
                content = $def.content
            }
        }
    }
} | Export-Csv -Path '.\cebuano_dictionary_parsed.csv' -NoTypeInformation -Encoding UTF8