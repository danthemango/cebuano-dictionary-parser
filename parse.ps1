
$entries = @()

$html = Get-Content '.\pg40074-images.html'
[xml]$xml = $html
if ($xml) {
    $res = Select-Xml -Xml $xml -XPath "//div[@class='div1 letter']"
    $res = $res | ForEach-Object { $_.Node.ChildNodes | Where-Object class -eq divBody }

    # this provides you with an array of sections for each letter, with child notes for each definition
    # e.g. $res[0].ChildNodes[15].InnerXml

    foreach ($node in $res[0].ChildNodes) {
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
                    $defText = $senseNode.NextSibling.InnerText

                    # Pair examples with translations
                    $examples = @()
                    $exampleNodes = $node.SelectNodes(".//i[@lang='ceb']")
                    foreach ($exNode in $exampleNodes) {
                        try {
                            $cebSentence = $exNode.InnerText.Trim()
                            $engTranslation = $exNode.NextSibling.InnerText.Trim()
                            $examples += [PSCustomObject]@{
                                cebuano = $cebSentence
                                english = $engTranslation
                            }
                        }
                        catch {
                            Write-Host "Could not parse $($exNode.InnerXml) $_"
                        }
                    }

                    $definitions += [PSCustomObject]@{
                        sense      = $senseNum
                        definition = $defText
                        examples   = $examples
                    }
                }

                $entries += [PSCustomObject]@{
                    word           = $word
                    lang           = $lang
                    part_of_speech = $pos
                    definitions    = $definitions
                }
            }
        }
    }

    return $entries

    # Convert to JSON
    # $entries | ConvertTo-Json -Depth 6 | Out-File "dictionary.json"


}
else {
    throw "could not convert"
}