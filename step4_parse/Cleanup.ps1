Write-Output "Start Cleanup."
$proj_path = "$PSScriptRoot\.."

# get the ids of all paragraph files that failed to tokenize
[int[]]$para_ids = Get-ChildItem "$proj_path\..\step2_split_paras\data\" | Select-Object -ExpandProperty Name | ForEach-Object { $_ -replace 'para_._', '' -replace '.xml', '' }
# get the tokenized ids
[int[]]$token_ids = Get-ChildItem "$proj_path\..\step3_tokenize\data\" | Select-Object -ExpandProperty Name | ForEach-Object { $_ -replace 'tokens_._', '' -replace '.csv', '' }
# get the para ids that aren't tokenized
$non_token_ids = Compare-Object $para_ids $token_ids -PassThru | Where-Object SideIndicator -eq '<='

# remove the parsed files
$non_token_ids | ForEach-Object {
    $id = $_
    Remove-Item "$proj_path\step4_parse\data\parse_*_$id.json"
    Remove-Item "$proj_path\step4_parse\errors\error_*_$id.txt"
}
Write-Output "Done Cleanup."