$paraCount = (Get-ChildItem step2_split_paras\data).Count
$tokenCount = (Get-ChildItem step3_tokenize\data).Count
$parseCount = (Get-ChildItem step4_parse\data).Count

$tokenErrorCount = (Get-ChildItem step3_tokenize\errors).Count
$parseErrorCount = (Get-ChildItem step4_parse\errors).Count

Write-Output "Paragraphs: $paraCount"
Write-Output "Tokenized: $tokenCount"
Write-Output "Parsed: $parseCount"

Write-Output "Tokenization Errors: $tokenErrorCount"
Write-Output "Parsing Errors: $parseErrorCount"

Write-Output "Tokenization Rate: $(($tokenCount / ($tokenCount + $tokenErrorCount) * 100).ToString('F2'))%"
Write-Output "Parsing Rate: $(($parseCount / ($parseCount + $parseErrorCount) * 100).ToString('F2'))%"

Write-Output "Paragraph Parsing Rate: $(($parseCount / $paraCount * 100).ToString('F2'))%"
