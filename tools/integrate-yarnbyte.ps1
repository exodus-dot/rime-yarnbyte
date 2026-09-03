# integrate-yarnbyte.ps1
# 把 rime-fast-xhup 的 飞鹤快拼 / 飞鹤快码 / Easy English 及其依赖整合进 rime-yarnbyte（rime-crane 的副本）。
#
# 用法：把本脚本放在 InputData 目录（与 switch-rime-currentdir.bat 同级），然后执行：
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\integrate-yarnbyte.ps1
#
# 前提：
#   InputData\rime-crane       原始 crane（只读，不会改动）
#   InputData\rime-fast-xhup   原始 fast-xhup（只读，不会改动）
#   InputData\rime-yarnbyte    rime-crane 的完整副本（本脚本只往里添加/生成文件，不改 crane 原有文件）
#
# 可重复执行：再次运行会覆盖上一次生成的 fast 相关文件，crane 文件不受影响。

param([string]$Base = $PSScriptRoot)
$ErrorActionPreference = 'Stop'

$Crane  = Join-Path $Base 'rime-crane'
$Fast   = Join-Path $Base 'rime-fast-xhup'
$Target = Join-Path $Base 'rime-yarnbyte'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:copied = @()
$script:generated = @()

function Read-Utf8([string]$p) { return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Utf8([string]$p, [string]$s) {
    $d = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    [System.IO.File]::WriteAllText($p, $s, $Utf8NoBom)
    $script:generated += $p.Substring($Target.Length + 1)
}
function Replace-Once([string]$s, [string]$old, [string]$new, [string]$what) {
    $i = $s.IndexOf($old)
    if ($i -lt 0) { throw "在上游文件里没找到预期片段（上游可能已更新，请人工检查）: $what" }
    if ($s.IndexOf($old, $i + 1) -ge 0) { throw "预期片段出现了多次: $what" }
    return $s.Substring(0, $i) + $new + $s.Substring($i + $old.Length)
}
function Copy-FromFast([string]$rel, [string]$destRel = $null) {
    if (-not $destRel) { $destRel = $rel }
    $src = Join-Path $Fast $rel
    $dst = Join-Path $Target $destRel
    if (-not (Test-Path -LiteralPath $src)) { throw "rime-fast-xhup 缺少文件: $rel" }
    $d = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $script:copied += $destRel
}
function Copy-DirFromFast([string]$rel) {
    $src = Join-Path $Fast $rel
    $dst = Join-Path $Target $rel
    if (-not (Test-Path -LiteralPath $src)) { throw "rime-fast-xhup 缺少目录: $rel" }
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Force -Path $dst | Out-Null }
    Get-ChildItem -LiteralPath $src -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dst $_.Name) -Force
        $script:copied += (Join-Path $rel $_.Name)
    }
}

# ---------------------------------------------------------------- 0. 前置检查
Write-Host "=== rime-yarnbyte 整合 ===" -ForegroundColor Cyan
Write-Host "crane : $Crane"
Write-Host "fast  : $Fast"
Write-Host "target: $Target"
foreach ($p in @($Crane, $Fast, $Target)) { if (-not (Test-Path -LiteralPath $p)) { throw "目录不存在: $p" } }
foreach ($f in @('xhup.schema.yaml', 'weasel.yaml', 'default.yaml', 'rime_ice.schema.yaml', 'double_pinyin_flypy.schema.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Target $f))) { throw "rime-yarnbyte 不像是 rime-crane 的副本，缺少 $f" }
}
foreach ($f in @('flypy_xhfast.schema.yaml', 'flyhe_fast.schema.yaml', 'easy_en.schema.yaml', 'default.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Fast $f))) { throw "rime-fast-xhup 缺少 $f" }
}
if (Test-Path -LiteralPath (Join-Path $Target 'flypy_xhfast.schema.yaml')) {
    Write-Host "rime-yarnbyte 里已有 fast 方案文件，本次将覆盖它们（crane 文件不动）。" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 1. 复制 fast-xhup 的方案与依赖（无同名冲突的文件）
Write-Host "`n[1/4] 复制 rime-fast-xhup 方案、词库、Lua、资源 ..." -ForegroundColor Yellow
$rootFiles = @(
    'flypy_xhfast.schema.yaml', 'flypy_xhfast.dict.yaml',
    'flyhe_fast.schema.yaml',   'flyhe_fast.dict.yaml',
    'easy_en.schema.yaml',      'easy_en.dict.yaml',
    'ecdict.schema.yaml',       'ecdict.dict.yaml',
    'flypy_radical.schema.yaml','flypy_radical.dict.yaml',
    'flypy_reverse.schema.yaml','flypy_reverse.dict.yaml',
    'symbols.custom.yaml', 'flypy_keymap.txt', 'predict.db',
    'flypy_chord_rule.yaml', 'calendar.yaml', 'custom_predict_rules.yaml'
)
foreach ($f in $rootFiles) { Copy-FromFast $f }
foreach ($f in @('flyhe_chars', 'flypy_base', 'flypy_chars', 'flypy_chars_ext', 'flypy_melt_eng')) { Copy-FromFast "cn_dicts\$f.dict.yaml" }
foreach ($f in @('cn_en_flypy', 'easy_en', 'ecdict', 'en_custom', 'en_ext_private')) { Copy-FromFast "en_dicts\$f.dict.yaml" }
Copy-DirFromFast 'lua'                    # 30 个 *.lua（与 crane 的 lua 无同名文件）
Copy-DirFromFast 'lua\lib'
Copy-DirFromFast 'lua\cold_word_records'
Copy-FromFast 'opencc\emoji_word.txt'
Copy-FromFast 'opencc\others.txt' 'opencc\others_xhup.txt'   # crane 的 opencc\others.txt 保持原样
Copy-FromFast 'LICENSE'  'LICENSE.rime-fast-xhup'
Copy-FromFast 'README.md' 'README.rime-fast-xhup.md'
foreach ($db in @('easy_en.userdb', 'flyhe_fast.userdb', 'flypy_xhfast.userdb', 'free_user_dict.userdb')) {
    $src = Join-Path $Fast $db
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $Target $db) -Recurse -Force
        $script:copied += "$db\"
    }
}
# 安全检查：绝不覆盖 crane 已有文件
$craneFiles = Get-ChildItem -LiteralPath $Crane -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\build\\' } | ForEach-Object { $_.FullName.Substring($Crane.Length + 1) }
$clash = $script:copied | Where-Object { $craneFiles -contains $_ }
if ($clash) { throw "内部错误：以下复制会覆盖 crane 文件，已中止: $($clash -join ', ')" }
Write-Host "  已复制 $($script:copied.Count) 个文件"

# ---------------------------------------------------------------- 2. 生成新文件
Write-Host "`n[2/4] 生成 default.custom.yaml / flypy_preset.yaml / easy_en.custom.yaml / OpenCC / custom_phrase_flypy ..." -ForegroundColor Yellow

# 2a. default.custom.yaml —— 方案列表合并（crane 的 default.yaml 原样不动）
Write-Utf8 (Join-Path $Target 'default.custom.yaml') @'
# default.custom.yaml —— rime-yarnbyte 整合版全局补丁
# encoding: utf-8
#
# 基底为 rime-crane 的 default.yaml（未改动）。本文件只做两件事：
#   1. 合并方案列表：crane 原有方案 + rime-fast-xhup 方案
#   2. 让方案选单记住 fast-xhup 方案用到的开关
#
# 小狼毫「输入法设定」勾选方案时会改写本文件的 patch/schema_list（注释会丢失）。
# 雾凇拼音(rime_ice)默认没有勾选，需要时在「输入法设定」里勾上即可。
#
# 飞鹤反查(flypy_reverse)、飞鹤拆字(flypy_radical)、ecdict、melt_eng、radical_pinyin、xhup_reverse
# 都是内部依赖，通过各方案的 schema/dependencies 自动编译，不列入此处。

patch:
  schema_list:
    # ---- rime-crane 原有方案 ----
    - schema: xhup                   # 小鹤音形
    - schema: double_pinyin_flypy    # 小鹤双拼
    # - schema: rime_ice             # 雾凇拼音（全拼），按需启用
    # ---- rime-fast-xhup 方案 ----
    - schema: flypy_xhfast           # 飞鹤快拼
    - schema: flyhe_fast             # 飞鹤快码
    - schema: easy_en                # Easy English

  # 追加 fast-xhup 方案的开关到记忆列表（crane 方案没有这些开关，不受影响）
  switcher/save_options/+:
    - char_mode
    - traditionalize

'@

# 2b. flypy_preset.yaml —— fast-xhup 自带 default.yaml 的 key_binder / recognizer / punctuator，供 fast 方案继承
Write-Utf8 (Join-Path $Target 'flypy_preset.yaml') @'
# flypy_preset.yaml —— rime-fast-xhup 方案专用的通用预设
# encoding: utf-8
#
# 来源：rime-fast-xhup/default.yaml 中的 key_binder / recognizer / punctuator 三节，内容逐字照搬。
#
# 为什么需要这个文件：
#   整合版的 default.yaml 是 rime-crane 的。crane 的 key_binder 里有「- = 翻页」「Control+Shift+3/4 切换」
#   等绑定，而飞鹤快拼把 - = 用作计算器 / 英文造词等编码，二者冲突。
#   fast-xhup 的三个方案（flypy_xhfast / flyhe_fast / easy_en）在各自的 *.custom.yaml 里把
#   key_binder/import_preset 与 recognizer/import_preset 从 default 改成了 flypy_preset，
#   于是它们继承的是本文件，crane 方案继承的仍是 default.yaml，互不干扰。
#
# import_preset 的解析规则：import_preset: flypy_preset 等价于 __include: flypy_preset:/<同名节点>

# 快捷键
key_binder:
  bindings:
    # 数字小键盘
    - {accept: KP_0, send: 0, when: composing}
    - {accept: KP_1, send: 1, when: composing}
    - {accept: KP_2, send: 2, when: composing}
    - {accept: KP_3, send: 3, when: composing}
    - {accept: KP_4, send: 4, when: composing}
    - {accept: KP_5, send: 5, when: composing}
    - {accept: KP_6, send: 6, when: composing}
    - {accept: KP_7, send: 7, when: composing}
    - {accept: KP_8, send: 8, when: composing}
    - {accept: KP_9, send: 9, when: composing}
    - {accept: KP_Add,      send: plus,     when: composing}
    - {accept: KP_Divide,   send: slash,    when: composing}
    - {accept: KP_Subtract, send: minus,    when: composing}
    - {accept: KP_Decimal,  send: period,   when: composing}
    - {accept: KP_Multiply, send: asterisk, when: composing}
    # [yarnbyte 用户偏好] 与 crane 方案一致，用 - = 翻页
    # 代价：飞鹤快拼里候选栏出现时，英文连字符和计算器的减号/等号会被翻页截走
    - {when: has_menu, accept: minus, send: Page_Up}
    - {when: has_menu, accept: equal, send: Page_Down}

# 处理符合特定规则的输入码，如网址、反查
recognizer:
  patterns:
    punct: "^v/([0-9]0?|[A-Za-z]+)$"
    email: "^[A-Za-z][-_.0-9A-Za-z]*@.*$"
    url: "^(www[.]|https?:|ftp[.:]|mailto:|file:).*$|^[a-z]+[.].+$"

# 标点符号（fast-xhup 版本）
punctuator:
  full_shape:
    " ": {commit: "　"}
    ",": {commit: ，}
    ".": {commit: 。}
    "<": [《, 〈, «, ‹]
    ">": [》, 〉, », ›]
    "/": [、, ､, "/", ／, ÷]
    "?": {commit: ？}
    ";": {commit: ；}
    ":": {commit: ：}
    "'": {pair: ["‘", "’"]}
    '"': {pair: ["“", "”"]}
    '\': [、, ＼]
    "|": [·, ｜, "§", "¦"]
    "`": ｀
    "~": ～
    "!": {commit: ！}
    "@": [＠, ☯]
    "#": [＃, ⌘]
    "%": [％, "°", "℃"]
    "$": [￥, "$", "€", "£", "¥", "¢", "¤"]
    "^": {commit: ……}
    "&": ＆
    "*": [＊, ·, ・, ×, ※, ❂]
    "(": （
    ")": ）
    "-": －
    "_": ——
    "+": ＋
    "=": ＝
    "[": [「, 【, 〔, ［]
    "]": [」, 】, 〕, ］]
    "{": [『, 〖, ｛]
    "}": [』, 〗, ｝]
  half_shape:
    ',': '，'
    '.': '。'
    "<": "《"
    ">": "》"
    "/": [／, ÷]
    "?": "？"
    ";": "；"
    ":": ":"
    "'": {pair: ["‘", "’"]}
    '"': {pair: ["“", "”"]}
    '\': "､"
    "|": [·, ｜, "§", "¦"]
    "`": "`"
    "~": "~"
    "!": "！"
    "@": "@"
    "#": "#"
    "%": "%"
    "$": "¥"
    "^": "……"
    "&": "&"
    "*": "*"
    "(": "（"
    ")": "）"
    "-": "-"
    "_": ——
    "+": "+"
    "=": "="
    "[": "「"
    "]": "」"
    "{": "【"
    "}": "】"

'@

# 2c. easy_en.custom.yaml（上游没有此文件）
Write-Utf8 (Join-Path $Target 'easy_en.custom.yaml') @'
# easy_en.custom.yaml —— rime-yarnbyte 整合版补丁（rime-fast-xhup 原项目没有此文件）
# encoding: utf-8
#
# 只做一件事：把继承来源从 crane 的 default.yaml 改为 flypy_preset.yaml，
# 避免 crane 的「- = 翻页」等全局按键绑定影响英文方案。
---

patch:
  key_binder/+:
    import_preset: flypy_preset
  recognizer/+:
    import_preset: flypy_preset

  # [yarnbyte 用户偏好] 候选排序固定，不按输入习惯动态调频：关闭用户词典（想恢复删掉下一行）
  translator/enable_user_dict: false

'@

# 2d. opencc/emoji_xhup.json —— fast 的 emoji.json 换名，crane 的 emoji.json 不动
Write-Utf8 (Join-Path $Target 'opencc\emoji_xhup.json') @'
{
	"name": "Chinese to Emoji (rime-fast-xhup)",
	"segmentation": {
		"type": "mmseg",
		"dict": {
			"type": "text",
			"file": "emoji_word.txt"
		}
	},
	"conversion_chain": [
		{
			"dict": {
				"type": "group",
				"dicts": [
					{
						"type": "text",
						"file": "emoji_word.txt"
					},
					{
						"type": "text",
						"file": "others_xhup.txt"
					}
				]
			}
		}
	]
}

'@

# 2f. [yarnbyte 用户偏好] crane 方案也固定候选排序（不动 crane 的 schema 文件，只加 custom 补丁）
Write-Utf8 (Join-Path $Target 'double_pinyin_flypy.custom.yaml') (((@'
# double_pinyin_flypy.custom.yaml —— rime-yarnbyte 用户偏好补丁（rime-crane 原项目没有此文件）
# encoding: utf-8
#
# [yarnbyte 用户偏好] 候选排序固定，不按输入习惯动态调频：关闭主翻译器的用户词典。
# 代价：不再自动记住新造的词组（可写进 custom_phrase_double.txt 手动固定，或用 pin_cand_filter 置顶）。
# 想恢复调频，删掉下面那一行即可。

patch:
  translator/enable_user_dict: false
'@) -replace "`r`n", "`n") + "`n")
Write-Utf8 (Join-Path $Target 'rime_ice.custom.yaml') (((@'
# rime_ice.custom.yaml —— rime-yarnbyte 用户偏好补丁（rime-crane 原项目没有此文件）
# encoding: utf-8
#
# [yarnbyte 用户偏好] 候选排序固定，不按输入习惯动态调频：关闭主翻译器的用户词典。
# 代价：不再自动记住新造的词组（可写进 custom_phrase.txt 手动固定，或用 pin_cand_filter 置顶）。
# 想恢复调频，删掉下面那一行即可。

patch:
  translator/enable_user_dict: false
'@) -replace "`r`n", "`n") + "`n")

# 2e. custom_phrase_flypy.txt —— fast 的 custom_phrase.txt 换名（双拼编码），crane 的 custom_phrase.txt（全拼）不动
$cp = Read-Utf8 (Join-Path $Fast 'custom_phrase.txt')
$cp = $cp -replace "`r`n", "`n"
$cp = Replace-Once $cp "#@/db_name`tcustom_phrase.txt`n" "#@/db_name`tcustom_phrase_flypy.txt`n" 'custom_phrase db_name'
$cp = Replace-Once $cp "#@/db_type`ttabledb`n" "#@/db_type`ttabledb`n#`n# [yarnbyte] 来自 rime-fast-xhup/custom_phrase.txt，编码为小鹤双拼，供 飞鹤快拼 / 飞鹤快码 使用。`n# crane 的 custom_phrase.txt（全拼编码）留给雾凇拼音，两者互不混用。`n" 'custom_phrase db_type'
Write-Utf8 (Join-Path $Target 'custom_phrase_flypy.txt') $cp

# ---------------------------------------------------------------- 3. 改写 fast 的两个 custom 补丁（去外观、去圆圈序号、改继承）
Write-Host "`n[3/4] 改写 flypy_xhfast.custom.yaml / flyhe_fast.custom.yaml ..." -ForegroundColor Yellow

# 3a. flypy_xhfast.custom.yaml
$s = Read-Utf8 (Join-Path $Fast 'flypy_xhfast.custom.yaml')
$s = $s -replace "`r`n", "`n"
$header = @'
# 飞鹤快拼方案的配置补丁 —— rime-yarnbyte 整合版
# 基于 rime-fast-xhup/flypy_xhfast.custom.yaml，整合时做了以下改动（搜索 [yarnbyte] 可定位）：
#   1. 去掉 menu/alternative_select_labels（圆圈序号 ①②③），候选序号保持 crane 的 1 2 3 4 5
#   2. 去掉 style/+ 整段，候选栏外观完全由 crane 的 weasel.yaml 决定
#   3. key_binder / recognizer 的 import_preset 从 default 改为 flypy_preset（见 flypy_preset.yaml）
#   4. schema/dependencies 追加 flypy_reverse，使反查词典随本方案自动编译，不必列入方案选单
#   5. emoji/opencc_config 改为 emoji_xhup.json（crane 的 emoji.json 保持原样）
#   6. custom_phrase/user_dict 改为 custom_phrase_flypy（crane 的 custom_phrase.txt 保持原样）
#

'@
$s = Replace-Once $s "# 飞鹤快拼方案的配置补丁`n# 覆盖 flypy_xhfast.schema.yaml 和 全局配置中的部分参数。`n# 在此方案下，这里的配置具有最高优先级。`n`n" ($header -replace "`r`n", "`n") 'flypy_xhfast 文件头'
$s = Replace-Once $s "    # 注释掉下行以恢复常规候选标签序号`n    alternative_select_labels: [①, ②, ③, ④, ⑤, ⑥, ⑦, ⑧, ⑨, ⓪]`n" "    # [yarnbyte] 已移除 alternative_select_labels（圆圈序号），保持 crane 的普通数字序号`n" 'flypy_xhfast 圆圈序号'
$styleOld = @'
  # 候选菜单布局样式
  style/+:
    font_point: 17                    # 候选字大小
    line_spacing: 5                   # 行间距大小
    show_paging: false                # 是否显示分页符号
    inline_preedit: false             # 编码位是否嵌入候选框
    text_orientation: horizontal      # 候选文字横向(horizontal)/纵向(vertical)
    candidate_list_layout: linear     # 候选菜单横向(linear)/纵向(stacked)


'@
$styleNew = @'
  # [yarnbyte] 已移除 style/+ 整段（font_point/line_spacing/inline_preedit 等），外观由 crane 的 weasel.yaml 统一控制

  # [yarnbyte] 反查词典 flypy_reverse 作为内部依赖随本方案编译（radical_lookup 与 Lua 反查需要）
  schema/dependencies/+:
    - flypy_reverse


'@
$s = Replace-Once $s ($styleOld -replace "`r`n", "`n") ($styleNew -replace "`r`n", "`n") 'flypy_xhfast style/+ 段'
$s = Replace-Once $s "  key_binder/+:`n    import_preset: default                    # 从 default.yaml 继承通用的`n" "  key_binder/+:`n    import_preset: flypy_preset               # [yarnbyte] 从 flypy_preset.yaml 继承（原为 default）`n" 'flypy_xhfast key_binder import_preset'
$s = Replace-Once $s "  recognizer/+:`n    patterns/+:`n" "  recognizer/+:`n    import_preset: flypy_preset               # [yarnbyte] 从 flypy_preset.yaml 继承（原为 default）`n    patterns/+:`n" 'flypy_xhfast recognizer'
$s = Replace-Once $s "  custom_phrase/+:                    # 自定义短语`n    comment_mark: `" 📌`"               # 注解标记`n" "  custom_phrase/+:                    # 自定义短语`n    user_dict: custom_phrase_flypy    # [yarnbyte] 双拼编码短语放 custom_phrase_flypy.txt，crane 的 custom_phrase.txt 留给雾凇全拼`n    comment_mark: `"`"                  # [yarnbyte 用户偏好] 去掉固定短语的 📌 标记（原为 `" 📌`"）`n" 'flypy_xhfast custom_phrase'
$s = Replace-Once $s "  flypy_key_map/+:                    # 小鹤双拼键位帮助`n" "  emoji/opencc_config: emoji_xhup.json  # [yarnbyte] 使用 fast-xhup 的 emoji_word.txt 词表（crane 的 emoji.json 不动）`n`n  flypy_key_map/+:                    # 小鹤双拼键位帮助`n" 'flypy_xhfast emoji'
# [yarnbyte 用户偏好] 关闭 Emoji 候选、固定候选排序
$s = Replace-Once $s "    - name: emoji`n      states: [🈚️, 😄]`n      reset: 1`n" "    - name: emoji`n      states: [🈚️, 😄]`n      reset: 0                        # [yarnbyte 用户偏好] 默认关闭 Emoji 候选（原为 1）`n" 'flypy_xhfast emoji 开关'
$s = $s.TrimEnd("`n") + "`n" + ((@'
  # ================= [yarnbyte 用户偏好] =================
  # 1) 候选栏不显示 Emoji：emoji 开关默认关闭（reset: 0 已在上方 switches 里设置）。
  #    临时想用时按 Control+Shift+4 开启，下次启动又恢复关闭。
  # 2) 候选排序固定，不按输入习惯动态调频：关闭主翻译器和英文翻译器的用户词典。
  #    代价：不再自动记住新造的词组（可用 Control+t 手动置顶、custom_phrase_flypy.txt 手动固定）。
  translator/enable_user_dict: false
  easy_en/enable_user_dict: false
  translator/contextual_suggestions: false   # 主翻译器不按上下文重排候选（语法模型只用于精准造词），保证位置固定

  # 3) 新词仍能记住，但记在独立的 free_user_dict 里，不碰主词库的排序：
  #    - 精准造词（` 逐字选）选完上屏即记入 free_user_dict（原配置不记）
  #    - 自由造词（`= 引导）本来就记入 free_user_dict
  #    - 普通输入时由 free_uses_word 翻译器提供这些自造词，权重 1.0 低于主翻译器 1.3，
  #      所以它们排在词库候选之后，词库本身的顺序不变
  make_sentence/+:
    enable_user_dict: true
    user_dict: free_user_dict
    contextual_suggestions: true      # 有语法模型（.gram）时按上下文挑字，避免拼出「复何」这类怪词
  free_uses_word/+:
    initial_quality: 1.0              # 原为 1.5（自造词压在词库候选之前）
'@) -replace "`r`n", "`n") + "`n"
Write-Utf8 (Join-Path $Target 'flypy_xhfast.custom.yaml') $s

# 3b. flyhe_fast.custom.yaml
$s = Read-Utf8 (Join-Path $Fast 'flyhe_fast.custom.yaml')
$s = $s -replace "`r`n", "`n"
$header = @'
# 飞鹤快码方案的配置补丁 —— rime-yarnbyte 整合版
# 基于 rime-fast-xhup/flyhe_fast.custom.yaml，整合时做了以下改动（搜索 [yarnbyte] 可定位）：
#   1. 去掉全部 style/* 项，候选栏外观完全由 crane 的 weasel.yaml 决定
#   2. key_binder / recognizer 的 import_preset 从 default 改为 flypy_preset（见 flypy_preset.yaml）
#   3. custom_phrase/user_dict 改为 custom_phrase_flypy（crane 的 custom_phrase.txt 保持原样）
#   4. 注释掉指向不存在词库的 melt_eng/dictionary: melt_eng_custom（本方案没启用 melt_eng）
#

'@
$s = Replace-Once $s "# 飞鹤快码方案的配置补丁`n# 覆盖 flyhe_fast.schema.yaml 的部分参数。`n# 在此方案下，这里的配置具有最高优先级`n" ($header -replace "`r`n", "`n") 'flyhe_fast 文件头'
$styleOld = @'
  "style/font_point": 18                        # 候选字大小
  "style/line_spacing": 5                       # 行间距大小
  "style/show_paging": false                    # 是否显示分页符号
  "style/inline_preedit": true                  # 编码位是否嵌入候选框
  # "style/horizontal": true                    # 候选菜单横向布局(true)/纵向布局(false)
  "style/candidate_list_layout": linear         # 候选菜单横向(linear)/纵向(stacked)
  "style/text_orientation": horizontal          # 候选文字横向(horizontal)/纵向(vertical)

'@
$s = Replace-Once $s ($styleOld -replace "`r`n", "`n") "  # [yarnbyte] 已移除 style/* 各项，外观由 crane 的 weasel.yaml 统一控制`n" 'flyhe_fast style 段'
$s = Replace-Once $s "  key_binder/+:`n    import_preset: default                      # 从 default.yaml 继承通用的`n" "  key_binder/+:`n    import_preset: flypy_preset                 # [yarnbyte] 从 flypy_preset.yaml 继承（原为 default）`n" 'flyhe_fast key_binder import_preset'
$meltNew = "  recognizer/+:`n    import_preset: flypy_preset                 # [yarnbyte] 从 flypy_preset.yaml 继承（原为 default）`n`n" +
           "  custom_phrase/+:`n    user_dict: custom_phrase_flypy              # [yarnbyte] 双拼编码短语放 custom_phrase_flypy.txt`n`n" +
           "  # [yarnbyte] 次翻译器：上游写的是 melt_eng/dictionary: melt_eng_custom，但 melt_eng_custom.dict.yaml 在上游也不存在，`n" +
           "  # 且本方案 engine/translators 未启用 melt_eng，故注释掉以免误导。如需启用请自建词库后取消注释。`n" +
           "  # melt_eng/dictionary: melt_eng_custom        # 挂载词库 melt_eng_custom.dict.yaml`n"
$s = Replace-Once $s "  # 次翻译器`n  melt_eng/dictionary: melt_eng_custom          # 挂载词库 melt_eng_custom.dict.yaml`n" $meltNew 'flyhe_fast melt_eng'
# [yarnbyte 用户偏好] 固定候选排序
$s = $s.TrimEnd("`n") + "`n" + ((@'
  # ================= [yarnbyte 用户偏好] =================
  # 候选排序固定，不按输入习惯动态调频：关闭主翻译器的用户词典。
  # 代价：不再自动记住新造的词组（可用 custom_phrase_flypy.txt 手动固定）。
  translator/enable_user_dict: false
'@) -replace "`r`n", "`n") + "`n"
Write-Utf8 (Join-Path $Target 'flyhe_fast.custom.yaml') $s

# weasel.custom.yaml：只写圆角微调；fast 的 weasel.yaml / weasel.custom.yaml 不复制。
# 若文件里已有小狼毫写入的 style/color_scheme，保留该行。
$wc = Join-Path $Target 'weasel.custom.yaml'
$keep = ''
if (Test-Path -LiteralPath $wc) { $m = [regex]::Match((Read-Utf8 $wc), '(?m)^\s*"?style/color_scheme"?:.*$'); if ($m.Success) { $keep = "  " + $m.Value.Trim() + "`n" } }
Write-Utf8 $wc ((((@'
# weasel.custom.yaml —— rime-yarnbyte 外观微调
# encoding: utf-8
#
# 外观整体沿用 rime-crane 的 weasel.yaml，这里只改圆角。
# 小狼毫「界面风格设定」选配色时会往本文件写 style/color_scheme，其余项会保留。

patch:
  style/layout/corner_radius: 2    # [yarnbyte 用户偏好] 候选窗口圆角，crane 原值 8，0 为直角
  style/layout/round_corner: 2     # [yarnbyte 用户偏好] 高亮色块圆角，crane 原值 8，0 为直角
'@) -replace "`r`n", "`n") + "`n") + $keep)

# ---------------------------------------------------------------- 4. 校验
Write-Host "`n[4/4] 校验引用完整性 ..." -ForegroundColor Yellow
$fail = @()
function Need([string]$rel, [string]$why) { if (-not (Test-Path -LiteralPath (Join-Path $Target $rel))) { $script:fail += "$rel  ($why)" } }
$schemas = @('xhup', 'double_pinyin_flypy', 'rime_ice', 'flypy_xhfast', 'flyhe_fast', 'easy_en', 'ecdict', 'flypy_radical', 'flypy_reverse', 'melt_eng', 'radical_pinyin', 'xhup_reverse')
foreach ($id in $schemas) {
    Need "$id.schema.yaml" '方案'
    $texts = @()
    foreach ($f in @("$id.schema.yaml", "$id.custom.yaml")) { $p = Join-Path $Target $f; if (Test-Path -LiteralPath $p) { $texts += Read-Utf8 $p } }
    $all = $texts -join "`n"
    # 词典
    foreach ($m in [regex]::Matches($all, '(?m)^\s*dictionary:\s*([A-Za-z0-9_]+)\s*(#.*)?$')) {
        $d = $m.Groups[1].Value
        if ($d -eq 'melt_eng_custom') { continue }
        Need "$d.dict.yaml" "方案 $id 的 dictionary"
        $dp = Join-Path $Target "$d.dict.yaml"
        if (Test-Path -LiteralPath $dp) {
            foreach ($t in [regex]::Matches((Read-Utf8 $dp), '(?m)^\s*-\s*"?([A-Za-z0-9_./-]+)"?\s*(#.*)?$')) {
                $tbl = $t.Groups[1].Value
                if ($tbl -match '^(cn_dicts|en_dicts|xhup_dicts)/') { Need "$tbl.dict.yaml" "词典 $d 的 import_tables" }
            }
        }
    }
    # Lua
    foreach ($m in [regex]::Matches($all, 'lua_(?:processor|translator|filter|segmentor)@\*([A-Za-z0-9_/]+)')) { Need "lua\$($m.Groups[1].Value -replace '/', '\').lua" "方案 $id 的 Lua" }
    # OpenCC
    foreach ($m in [regex]::Matches($all, '(?m)^\s*(?:"?[\w/]*opencc_config"?):\s*([A-Za-z0-9_]+\.json)')) {
        $j = $m.Groups[1].Value
        if ($j -in @('s2t.json', 't2s.json', 's2hk.json', 's2tw.json', 's2twp.json')) { continue }
        Need "opencc\$j" "方案 $id 的 opencc_config"
        $jp = Join-Path $Target "opencc\$j"
        if (Test-Path -LiteralPath $jp) { foreach ($t in [regex]::Matches((Read-Utf8 $jp), '"file":\s*"([^"]+)"')) { Need "opencc\$($t.Groups[1].Value)" "opencc $j 引用" } }
    }
    # import_preset / __include
    foreach ($m in [regex]::Matches($all, '(?m)^\s*(?:import_preset:\s*([A-Za-z0-9_.]+)|__include:\s*([A-Za-z0-9_.]+):/)')) {
        $c = $m.Groups[1].Value; if (-not $c) { $c = $m.Groups[2].Value }   # __include 不带 :/ 的是本文件内锚点，不是文件
        if ($c -eq 'symbols') { continue }   # symbols.yaml 由小狼毫共享目录提供
        if ($c -like '*.schema.yaml') { Need $c "方案 $id 的 __include" } else { Need "$c.yaml" "方案 $id 的 import_preset/__include" }
    }
    # 圆圈序号 / 外观残留（只查 fast 方案）
    if ($id -in @('flypy_xhfast', 'flyhe_fast', 'easy_en')) {
        foreach ($line in ($all -split "`n")) {
            $code = ($line -split '#', 2)[0]
            if ($code -match 'alternative_select_labels') { $fail += "$id 仍含 alternative_select_labels: $($line.Trim())" }
            if ($code -match '^\s*"?style/') { $fail += "$id 仍含 style 覆盖: $($line.Trim())" }
        }
    }
}
Need 'flypy_keymap.txt' 'flypy_key_map 用户词典'
Need 'custom_phrase_flypy.txt' '双拼固定短语'
Need 'custom_phrase.txt' 'crane 固定短语'
Need 'symbols.custom.yaml' 'fast 方案符号表'
Need 'predict.db' '联想预测库'
Need 'lua\lib\rime_helper.lua' 'fast Lua 公共库'
Need 'weasel.yaml' 'crane 外观'

$fail = $fail | Sort-Object -Unique
Write-Host ""
if ($fail.Count -gt 0) {
    Write-Host "校验发现问题：" -ForegroundColor Red
    $fail | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "校验通过：所有 dictionary / import_tables / Lua / OpenCC / import_preset 引用均存在，fast 方案无圆圈序号与外观覆盖。" -ForegroundColor Green
Write-Host "复制文件 $($script:copied.Count) 个，生成/改写文件 $($script:generated.Count) 个：" -ForegroundColor Green
$script:generated | ForEach-Object { Write-Host "  + $_" }
Write-Host ""
Write-Host "下一步：运行 switch-rime-currentdir.bat 选择 rime-yarnbyte，或在小狼毫托盘菜单点「重新部署」。" -ForegroundColor Cyan
Write-Host "首次部署要编译 flypy_base(25MB)、ecdict(28MB) 等词库，通常需要 2~5 分钟，请等托盘弹出「部署完成」再试。" -ForegroundColor Cyan
exit 0
