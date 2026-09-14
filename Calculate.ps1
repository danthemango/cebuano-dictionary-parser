# successfully parsed counts
$paraCount = (Get-ChildItem step2_split_paras\data).Count
$tokenCount = (Get-ChildItem step3_tokenize\data).Count
$parseCount = (Get-ChildItem step4_parse\data).Count
# now get the error counts in the \error folders:
$tokenErrorCount = (Get-ChildItem step3_tokenize\errors).Count
$parseErrorCount = (Get-ChildItem step4_parse\errors).Count

# output absolute numbers
Write-Output "Paragraphs: $paraCount"
Write-Output "Tokenized: $tokenCount"
Write-Output "Parsed: $parseCount"

# output absolute error numbers
Write-Output "Tokenization Errors: $tokenErrorCount"
Write-Output "Parsing Errors: $parseErrorCount"

# output percentage of tokens successfully tokenized: $tokenCount / ($tokenCount + $tokenErrorCount)
Write-Output "Tokenization Rate: $(($tokenCount / ($tokenCount + $tokenErrorCount) * 100).ToString('F2'))%"
Write-Output "Parsing Rate: $(($parseCount / ($parseCount + $parseErrorCount) * 100).ToString('F2'))%"

# output percentage of paragraphs successfully parsed: $parseCount / ($paraCount)
Write-Output "Paragraph Parsing Rate: $(($parseCount / $paraCount * 100).ToString('F2'))%"
