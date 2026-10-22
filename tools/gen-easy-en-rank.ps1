# gen-easy-en-rank.ps1
# 从 ECDICT 词库提取词频，生成 lua/easy_en_rank.txt（每行：小写单词<TAB>权重），
# 供 lua/easy_en_rank.lua 对 Easy English 方案的候选重排。只影响 easy_en 方案。
#
# 用法（在仓库根目录）：powershell -NoProfile -File tools\gen-easy-en-rank.ps1 [-MinWeight 5]
param([int]$MinWeight = 5)

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'en_dicts\ecdict.dict.yaml'
$dst = Join-Path $root 'lua\easy_en_rank.txt'

$best = @{}
$inBody = $false
foreach ($line in [System.IO.File]::ReadLines($src)) {
    if (-not $inBody) { if ($line -eq '...') { $inBody = $true }; continue }
    $f = $line.Split("`t")
    if ($f.Count -lt 3) { continue }
    $w = 0
    if (-not [int]::TryParse($f[2], [ref]$w) -or $w -lt $MinWeight) { continue }
    $k = $f[0].ToLowerInvariant()
    if ($k -notmatch "^[a-z][a-z'-]*$") { continue }
    if (-not $best.ContainsKey($k) -or $best[$k] -lt $w) { $best[$k] = $w }
}
$lines = $best.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)`t$($_.Value)" }
[System.IO.File]::WriteAllText($dst, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
"$($best.Count) words -> $dst"
