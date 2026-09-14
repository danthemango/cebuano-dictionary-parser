$paraCount = (Get-ChildItem step2_split_paras\data).Count
$tokenCount = (Get-ChildItem step3_tokenize\data).Count
$parseCount = (Get-ChildItem step4_parse\data).Count

# output absolute numbers
# output percentage of $tokenCount / $paraCount
# output percentage of $parseCount / $tokenCount

Write-Output "Paragraphs: $paraCount"
Write-Output "Tokenized: $tokenCount"
Write-Output "Parsed: $parseCount"
Write-Output "Tokenization Rate: $(($tokenCount / $paraCount * 100).ToString('F2'))%"
Write-Output "Parsing Rate: $(($parseCount / $tokenCount * 100).ToString('F2'))%"