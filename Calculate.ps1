$paraCount = (Get-ChildItem step2_split_paras\data).Count
$tokenCount = (Get-ChildItem step3_tokenize\data).Count
$parseCount = (Get-ChildItem step4_parse\data).Count

# output absolute numbers
# output percentage of $tokenCount / $paraCount
# output percentage of $parseCount / $tokenCount

Write-Host "Paragraphs: $paraCount"
Write-Host "Tokenized: $tokenCount"
Write-Host "Parsed: $parseCount"
Write-Host "Tokenization Rate: $(($tokenCount / $paraCount * 100).ToString('F2'))%"
Write-Host "Parsing Rate: $(($parseCount / $tokenCount * 100).ToString('F2'))%"