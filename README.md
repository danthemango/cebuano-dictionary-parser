# cebuano-dictionary-parser
convert cebuano dictionary to csv

Powershell 7+ recommended.

Original content source: https://www.gutenberg.org/files/40074/40074-h/40074-h.htm

- In powershell, download the file:
```ps1
Invoke-WebRequest -Uri "https://www.gutenberg.org/files/40074/40074-h/40074-h.htm" -OutFile "cebuano-dictionary.html"
```

- Skip digital signing requirement:
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

- Run html fixer:
```ps1
.\fix-html.ps1 -inpath ".\cebuano-dictionary.html"
```

- `.\run.ps1`

# TODO
- [ ] it currently fails on links to specific types and numbers (e.g. "= -kung v, n 1,2,3" which says the definition is equal to the linked definitions but only the verb and 1, 2, and 3 of the noun definitions)
    - see ábang, agdul, abi
- [ ] abrasadur - failed because of link numbering
- [ ] ábi: failed class tokenizing
- [ ] it fails to parse when there is a cebuano word in the middle of a translation (see abay)
- [ ] can't parse the phrase "short form", I likely need another entry in definitions