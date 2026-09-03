# rime-yarnbyte

小狼毫（Weasel）用户目录，个人整合版：

- 基底：[rime-crane](https://github.com/kchen0x/rime-crane)（小鹤音形 / 小鹤双拼 / 雾凇拼音），外观、全局按键、词库全部沿用，文件未改动。
- 加入：[rime-fast-xhup](https://github.com/boomker/rime-fast-xhup) 的 飞鹤快拼 / 飞鹤快码 / Easy English 及其全部依赖，通过 `*.custom.yaml` 补丁接入，不覆盖任何 crane 文件。
- 个人偏好：候选排序固定（关闭用户词典调频）、不显示 Emoji 候选、候选栏圆角 2、所有方案统一用 `-` `=` 翻页。

整合过程、冲突处理和校验结果见 [docs/2026-09-03-整合报告.md](docs/2026-09-03-整合报告.md)。

## 目录说明

| 路径 | 来源 | 说明 |
|---|---|---|
| `default.yaml`、`weasel.yaml`、`xhup*`、`rime_ice*`、`double_pinyin_flypy*`、`cn_dicts/`（雾凇六个词库）、`xhup_dicts/`、`lua/`（crane 部分）、`opencc/emoji.json` 等 | rime-crane | 原样 |
| `flypy_xhfast*`、`flyhe_fast*`、`easy_en*`、`ecdict*`、`flypy_radical*`、`flypy_reverse*`、`cn_dicts/flypy_*`、`cn_dicts/flyhe_*`、`en_dicts/easy_en*` 等、`lua/`（fast 部分及 `lib/`）、`symbols.custom.yaml`、`flypy_keymap.txt`、`predict.db` | rime-fast-xhup | 原样 |
| `default.custom.yaml`、`weasel.custom.yaml`、`flypy_preset.yaml`、`*.custom.yaml`（含 `[yarnbyte]` 标记）、`custom_phrase_flypy.txt`、`opencc/emoji_xhup.json`、`opencc/others_xhup.txt` | 本仓库 | 整合与偏好补丁 |
| `tools/integrate-yarnbyte.ps1` | 本仓库 | 从 rime-crane 副本 + rime-fast-xhup 重新生成 fast 部分与偏好补丁，可重复执行 |
| `tools/switch-rime-currentdir.*` | 本仓库 | 在多套 Rime 配置目录之间切换（junction 到 `%APPDATA%\Rime`）并重新部署 |

不入库的文件（见 `.gitignore`）：`build/`（部署产物）、`*.userdb/`（用户词频）、`installation.yaml`、`user.yaml`、`*.gram`（语法模型）。

## 在新机器上恢复

1. 安装小狼毫。
2. 克隆本仓库到任意目录，例如 `D:\Rime\rime-yarnbyte`。
3. 把 `%APPDATA%\Rime` 指向它（用 `tools/switch-rime-currentdir.bat` 建 junction，或直接把内容复制进去），重新部署。首次部署要编译约 130 MB 词库，需要几分钟。
4. 可选：语法模型 `zh-hans-t-essay-bgw.gram`（206 MB，[下载](https://github.com/boomker/rime-fast-xhup/releases/download/v1.0.0/zh-hans-t-essay-bgw.gram)）放到根目录，只影响飞鹤快拼的精准造词。

## 更新上游

- rime-crane 更新：本仓库保留了它的 git 历史，远程名为 `crane-upstream`，可以直接 `git fetch crane-upstream` 后合并。
- rime-fast-xhup 更新：把新版放到与本目录同级的 `rime-fast-xhup`，运行 `tools/integrate-yarnbyte.ps1 -Base <上级目录>`。脚本用字符串匹配改写上游补丁，上游改动了对应行会报错停下，需要人工跟进。

## 快速参考

| 动作 | 飞鹤快拼 |
|---|---|
| 单字加辅码 | `fu/pw` 或 `fu/p`，唯一时自动上屏 |
| 两字词加辅码 | `fuhe/rp`（尾字头码 + 首字头码） |
| 按声调筛字 | `fu/M`（I U N M 对应一二三四声） |
| 单字优先（音形四码顶屏） | 有候选时按 Ctrl+s 切换，会记住 |
| 精准造词 | `` fu`pwhe`rk ``，选完记入 free_user_dict，排在词库候选之后 |
| 自由造词 | `` `= `` 引导 |
| 临时打开 Emoji | Ctrl+Shift+4 |
