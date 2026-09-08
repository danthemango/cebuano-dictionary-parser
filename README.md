# cebuano-dictionary-fixed-parser
convert cebuano dictionary to csv

## Project Progress
- First 200 words: ![92% Success](https://img.shields.io/badge/success-92%25-green "92% success")
- First 1000 words: ![87% Success](https://img.shields.io/badge/success-87%25-green "87% success")

## prereqs
- Install Powershell 7
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## step 0, get HTML
```powershell
mkdir step0_get_html
Invoke-WebRequest -Uri "https://www.gutenberg.org/files/40074/40074-h/40074-h.htm" -OutFile "step0_get_html\cebuano-dictionary.html"
```

## step 1, clean HTML
```powershell
mkdir step1_fix_html
step1_fix_html\fix-html.ps1 -Inpath step0_get_html\cebuano-dictionary.html
```

## step 2, split definition paragraphs
```powershell
mkdir step2_split_paras
step2_split_paras\SplitParas.ps1
```

## step 3, tokenize
```powershell
mkdir step3_tokenize
# TODO
```

## step 4, parse
```powershell
mkdir step4_parse
# TODO
```

- `.\run.ps1 -Limit 100`

# Testing
```ps1
Install-Module Pester
Invoke-Pester
.\tests\Tokenize.Functions.Tests.ps1
```

```
Tests completed in 700ms
Tests Passed: 21, Failed: 1, Skipped: 0, Inconclusive: 0, NotRun: 0

Starting discovery in 1 files.
Discovery found 22 tests in 113ms.
Running tests.
```

# TODO
- [ ] it currently fails on links to specific types and numbers (e.g. "= -kung v, n 1,2,3" which says the definition is equal to the linked definitions but only the verb and 1, 2, and 3 of the noun definitions)
    - see ábang, agdul, abi
- [ ] abrasadur - failed because of link numbering (CEBWORD "2" following link)
- [ ] ábi: failed class tokenizing
- [ ] it fails to parse when there is a cebuano word in the middle of a translation (see abay)
    - we may use the fact that a translation will always end have punctuation separating the cebuano phrase from the
    english phrase, it's usually a comma separating them and sometimes a question mark or exclamation mark, but never a period.
    The english phrase will always end in a period.
- [ ] can't parse the phrase "short form", I likely need another entry in definitions
- [ ] can't parse link followed by bracketed explanation (e.g. kadtu (dialectical), adtu (colloquial))