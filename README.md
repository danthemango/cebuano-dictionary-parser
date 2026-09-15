# cebuano-dictionary-fixed-parser
convert cebuano dictionary to csv

## Project Progress
- Tokenization: ![99.57% Successful](https://img.shields.io/badge/success-99%25-green "99.57% Successful")
- Parsing: ![93.41% Successful](https://img.shields.io/badge/success-93%25-green "93.41% Successful")

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
step1_fix_html\fix-html.ps1 -Inpath step0_get_html\cebuano-dictionary.html
```

## step 2, split definition paragraphs
```powershell
step2_split_paras\SplitParas.ps1
```

## optional: create index
```powershell
step2_split_paras\CreateIndex.ps1
```
This should write `step2_split_paras\index.csv`

## step 3, tokenize
```powershell
step3_tokenize\TokenizeAll.ps1
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
## major
Let me start by correctly parsing the 5 longest definitions, and then checking everything else:
- [x] 13092 : this is successfully parsing, it is messing up the order of conjugations but I don't care particularly
- [ ] 10652
- [ ] 15295
    - [ ] fix `(<i lang=""cebword"">see also</i> 3c <i lang=""cebword"">and</i> 4d .)`
- [ ] 10583
    - [ ] fix `<i lang=\"cebword\">‘Wà na pud tingáli nay kwarta.’—‘May láin pa?’</i>`
    - (should be "ceb" instead of "cebword")
- [ ] 20434

note: the `<i lang="cebword>english phrase</i>` is a common pattern I see that require one-off exceptions, which is one of the most common reason for parsing failures.

## manual fix
- "in set phrase:" or "in set phrases"
    - [ ] 8781
    - [ ] 11979
    - [ ] 13774
    - [ ] 13875
    - [ ] 14692

## rest
- [ ] create index of word to ID (since we have special chars in many words, I don't think I can put the word as the filename, so I need a table of contents or something instead)
- [ ] move all tokenize tests into expected folder
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
- [ ] parse `"TEXT","= <span class=""sc"" lang=""ceb"">palabi</span>, <i lang=""cebword"">2</i>."`
- [ ] add tokenize exception to 18585, failed to parse `<i lang="ceb"><b>1</b>.</i>` (I think it's a formatting mistake, strip the i tag)
- [ ] review 15 `"CEBWORD","(→)" "LINK","abága: v"`
- [ ] parse "short form:" and "short form for" defs

## diary
### 2026-09-14
- I realized previously that there are a few tokenized defs that have an conjugation, I've allowed conjugation
parsing without needing a definition body.
- I realized today that I've duplicated the conjugation parsing step as a result, so I'll merge them together again.
- I just realized I expect a WordType def to have EITHER a DefEx OR a NumDef, but that fails on def 108, which has both.
I'll loosen the rules.
    - I'll also allow a cebword-only definition, if a conjugation is intended then this may ruin the parsing
    but I think that would indicate a badly written definition anyway.
- [ ] if the def is only text, I'd like it to be only text
- [ ] I want a -limit option in the *All.ps1 scripts
- I found def 150 is failing because of something related to DefBody, I think I'll loosen the rules there too
- 324 is failing because of a "see also" section, which the script can't tokenize yet
    - [ ] throw exceptions on tokenize "see also"
- 485 is failing because of `"TEXT","<corr id=""xd20e15781"" title=""Not in source""></corr>"`
    - [ ] just remove a text segment with only a `<corr>` (I'm not sure if these will be useful, perhaps I should tokenize it and include some metadata on the def?)
- 897 is failing because of a `short for` segment
    - [ ] throw exception on `short for`
- it appears a single letter may be used as if it's a numbered segment. I don't have much in the way of parsing sub-numbers, but I think if I find a single letter the html tag is different between an adjective (wordtype 'a') and numbered 'a'.

### 2026-09-15
- the changes yesterday pushed the total parsing rate from 93.8% to 98.8%
- [x] add 1535 to parse and token testing
- [x] update num-parsing to include `<b>a</b>` `<b>b</b>` `</b>c</b>`
    - sub-numbered sections may be introduced with only a bolded letter (e.g. <b>a</b> <b>b</b>)
    - I changed my tokenizer to be a bit more liberal than necessary, I need a more precise tokenizer if the dictionary writers aren't as precise, but it should be sufficient.
    - the new logic is, possibly comma separated numbers and chars up to length 3 in a bold html tag
- [x] fix 485
    - [x] strip corr segments
    - I will just remove all corr elements, which I think are corrections. I could do the extra work of capturing them and keeping
    them as metadata, but it could make the parser much more complicated and I don't understand what it means or how it could be
    useful.
- [x] fix 13875
    - [x] wrong tokenization for `"CEBWORD","b1"`, `"CEBWORD","b2"`
    - fix `<b lang="ceb">` tags if they have a digit in the content, these are just badly formatted content.
    - the fix resulted in a bad parse on 150 (see below)
- elevate the "CopyExpecteds" script so all of the testing files are being updated for both tokenization and parsing.
- [x] fix 150: accept a wtdef in the body of a numbdef
- [ ] fix 686: links after examples
- [x] throw exceptions on specific keywords: "see also", "short for", "cf."
- I think some are failing because of number > number
- [ ] rewrite the tokenizeall and tokenize ID so I can move error files correctly
- [x] fix 1632, class after cebword on numdef
- [x] fix 1535 parsing is stuck
- [x] fix 1535, accept a nested number def instead of a defex
