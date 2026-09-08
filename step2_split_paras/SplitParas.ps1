$outdir = "step2_split_paras\data"
mkdir -Force $outdir

# strip pagenums from content
# <span class="pagenum">[<a id="xd20e22720" href="#xd20e22720">40</a>]</span>
function Remove-PageNums {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    [string] $NewContent = [regex]::Replace($Content, '<span[^>]*class="pagenum"[^>]*>.*?</span>', '', $opts)
    return $NewContent
}

# look for paragraphs inside of each letter div
function Split-Paragraphs {
    param (
        [Parameter(Mandatory=$true)]
        [xml]$Xml
    )

    foreach ($section in Select-Xml -Xml $Xml -XPath "//div[@class='div1 letter']") {
        foreach ($node in $section.Node) {
            # strip the text 'letter.' from id:
            $letter = $node.id -replace "^letter\.", ""

            $divBodies = $node.ChildNodes | Where-Object class -eq divBody
            foreach ($divBody in $divBodies) {
                foreach ($para in $divBody.p) {
                    $content = $para.InnerXML.Trim() -replace "\s+", " "

                    # remove page numbers
                    $content = Remove-PageNums -Content $content

                    # set content as a token of type text
                    $contentToken = [PSCustomObject]@{
                        Type    = "TEXT"
                        Content = $content
                    }

                    [PSCustomObject]@{
                        Letter  = $letter
                        Tokens  = @($contentToken)
                        Content = $content
                    }
                }
            }
        }
    }
}

[xml]$xml = Get-Content -Path 'step1_fix_html\cebuano-dictionary-fixed.html'
$paragraphs = Split-Paragraphs -Xml $xml
for ($i = 0; $i -lt $paragraphs.Count; $i++) {
    $para = $paragraphs[$i]
    $letter = $para.Letter
    $filename = "$outdir\para_${letter}_$($i).xml"
    "<root>$($para.Content)</root>" | Set-Content -Path $filename
}
