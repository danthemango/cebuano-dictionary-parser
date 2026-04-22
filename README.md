# cebuano-dictionary-fixed-parser
convert cebuano dictionary to csv

Powershell 7+ recommended.

Original content source: https://www.gutenberg.org/files/40074/40074-h/40074-h.htm

- In powershell, download the file:
```ps1
Invoke-WebRequest -Uri "https://www.gutenberg.org/files/40074/40074-h/40074-h.htm" -OutFile "cebuano-dictionary-fixed.html"
```

- Skip digital signing requirement:
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

- Run html fixer:
```ps1
.\fix-html.ps1 -Inpath .\cebuano-dictionary.html -Outpath .\cebuano-dictionary-fixed.html
```

- `.\run.ps1 -Limit 100`

# Testing
- `Install-Module Pester`
- `Invoke-Pester`

# Progress
- First 100 words: ![91% Success](https://img.shields.io/badge/success-91%25-green "91% success")
- First 1000 words: ![84% Success](https://img.shields.io/badge/success-84%25-green "84% success")

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