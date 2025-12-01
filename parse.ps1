
$entries = @()

foreach ($node in $res[0].ChildNodes) {
    # Skip non-entry nodes
    if ($node.nodeName -ne "#text") {
        $wordNode = $node.SelectSingleNode(".//b[@id]")
        if ($wordNode) {
            $word = $wordNode.InnerText
            $lang = $wordNode.GetAttribute("lang")
            $posNode = $node.SelectSingleNode(".//i[1]")
            $pos = if ($posNode) { $posNode.InnerText } else { "" }

            # Extract definitions and examples
            $definitions = @()
            $senseNodes = $node.SelectNodes(".//b[not(@id)]")
            foreach ($senseNode in $senseNodes) {
                $senseNum = $senseNode.InnerText
                # Get text after this sense until next <b>
                $defText = $senseNode.NextSibling.InnerText
                $examples = ($node.SelectNodes(".//i[@lang='ceb']") | ForEach-Object { $_.InnerText })
                $definitions += [PSCustomObject]@{
                    sense = $senseNum
                    definition = $defText
                    examples = $examples
                }
            }

            $entries += [PSCustomObject]@{
                word = $word
                lang = $lang
                part_of_speech = $pos
                definitions = $definitions
            }
        }
    }
}

$entries

# Convert to JSON
# $entries | ConvertTo-Json -Depth 5 | Out-File "dictionary.json"
