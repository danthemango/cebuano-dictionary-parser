# cebuano-dictionary-parser
convert cebuano dictionary to csv

Original content source: https://www.gutenberg.org/files/40074/40074-h/40074-h.htm

in powershell to download the file:
```ps1
Invoke-WebRequest -Uri "https://www.gutenberg.org/files/40074/40074-h/40074-h.htm" -OutFile "cebuano-dictionary.html"
```

skip digital signing requirement:
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Parse:
```ps1
.\parse.ps1 -inpath ".\cebuano-dictionary.html" -outpath ".\cebuano_dictionary_parsed.csv"
```
