# cebuano-dictionary-parser
convert cebuano dictionary to csv

Original content source: https://www.gutenberg.org/files/40074/40074-h/40074-h.htm

In powershell, download the file:
```ps1
Invoke-WebRequest -Uri "https://www.gutenberg.org/files/40074/40074-h/40074-h.htm" -OutFile "cebuano-dictionary.html"
```

Skip digital signing requirement:
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Run html fixer:
```ps1
.\fix-html.ps1 -inpath ".\cebuano-dictionary.html"
```

Check how to run this script using help:
```ps1
Get-Help .\Parse-Dict.ps1 -Examples
```

Then use the script.
