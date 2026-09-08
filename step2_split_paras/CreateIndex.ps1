$files = Get-ChildItem "$PSScriptRoot\data" -Filter *.xml
$results = @()
foreach ($file in $files) {
    # extract the ceb word (first b element with lang="ceb") from the xml file
    # e.g. "<root><b lang="ceb">yungki</b><i>n</i> anvil. <i lang="ceb">Yungki ang dukdúkan sa binágang puthaw,</i> Red-hot metals are hammered on the anvil.</root>"
    $xml = [xml](Get-Content $file.FullName)
    $word = $xml.root.b | Where-Object { $_.lang -eq "ceb" } | Select-Object -First 1 -ExpandProperty InnerText
    $results += [PSCustomObject]@{
        Word = $word
        TokenFile = $file.Name
    }
}
$results | Export-Csv -Path "step2_split_paras\index.csv"