$html = Get-Content '.\pg40074-images.html'
[xml]$xml = $html
if ($xml)
{
    $res = Select-Xml -Xml $xml -XPath "//div[@class='div1 letter']"
    return $res | ForEach-Object { $_.Node.ChildNodes | Where-Object class -eq divBody }

    # this provides you with an array of sections for each letter, with child notes for each definition
    # e.g. $res[0].ChildNodes[15].InnerXml
}
else
{
    # throw "could not convert"
}
