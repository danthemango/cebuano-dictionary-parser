$paraCount = (Get-ChildItem step2_split_paras\data).Count
$tokenCount = (Get-ChildItem step3_tokenize\data).Count
$parseCount = (Get-ChildItem step4_parse\data).Count

$tokenErrorCount = (Get-ChildItem step3_tokenize\errors).Count
$parseErrorCount = (Get-ChildItem step4_parse\errors).Count

Write-Output "Tokenization Rate: $tokenCount / $($tokenCount + $tokenErrorCount) $(($tokenCount / ($tokenCount + $tokenErrorCount) * 100).ToString('F2'))%"
Write-Output "Parsing Rate: $parseCount / $($parseCount + $parseErrorCount) $(($parseCount / ($parseCount + $parseErrorCount) * 100).ToString('F2'))%"
Write-Output "Total Paragraph Parsing Rate: $parseCount / $paraCount $(($parseCount / $paraCount * 100).ToString('F2'))%"
