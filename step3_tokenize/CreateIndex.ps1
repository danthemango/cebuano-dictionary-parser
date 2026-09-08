$files = Get-ChildItem "$PSScriptRoot\data"
$results = @()
foreach ($file in $files) {
    $word = Import-Csv $file.FullName | Where-Object Type -eq CEBWORD | Select-Object -First 1 -ExpandProperty Content
    $results += [PSCustomObject]@{
        Word = $word
        TokenFile = $file.Name
    }
}
$results | Export-Csv -Path "step3_tokenize\index.csv"