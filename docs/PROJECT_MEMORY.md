# 项目记忆与接续记录

整理日期：2026-10-22。本文将 Claude 的本机项目记录转换为仓库内可持续维护的记忆。
历史记录只作为背景，涉及当前行为时以源文件和实际验证为准。

## 记忆来源

- Claude 项目会话：`C:/Users/Administrator/.claude/projects/D--WorkSpace-InputData-rime-yarnbyte/a9fa1dbb-ef1e-453a-b902-2ae6d7eb4e2b.jsonl`。
- 该项目的 Claude `memory/` 目录存在，但本次检查时为空。
- 旧 Rime 记忆：`C:/Users/Administrator/.claude/projects/C--Users-Administrator-AppData-Roaming-Rime/memory/`。
- 本仓库 Git 历史、README、`docs/2026-09-03-整合报告.md` 和当前工作区。
- 未复制其他项目的聊天记录或个人数据。

## 项目定位及偏好

以 rime-crane 为基底，整合 rime-fast-xhup 的飞鹤快拼、飞鹤快码和英文方案。
外观以 crane 为基础，个人补丁维护于本仓库；候选固定排序、默认不显示 Emoji、
候选窗和高亮圆角为 2、`-` / `=` 翻页。Firestorm Viewer 使用独立编码窗口。

飞鹤快拼的精准造词写入独立 `free_user_dict`，不干扰主词库排序。
快拼中切换 ASCII 模式是直接英文输入；独立 Easy English 方案负责英文候选和补全。
当前快拼补丁含 `Ctrl+Shift+E` 切换 Easy English 的绑定。

## 最近进度

当前已提交的最后一项为 `21314a5`：补充英文缩写及 `am`，避免 `ai` 被拆成 `a i`。
此前已提交：

- Easy English 使用 BlindingDark/rime-easy-en 方案文件，再叠加本仓库定制。
- `lua/easy_en_rank.lua` 使用固定词频排序，仅挂载于 Easy English。
- `lua/easy_en_enhance.lua` 内置纯 Lua 拆词，词频来自 `lua/easy_en_rank.txt`，
  当前 custom 启用此路径，不依赖外部 wordninja。
- `lua/easy_en_punct.lua` 处理候选显示时的标点上屏，移除自动补的尾部空格。

词频表由 `tools/gen-easy-en-rank.ps1` 从 `en_dicts/ecdict.dict.yaml` 提取。

## 接手时已有的未提交改动

以下记录是接手快照，不表示已经测试或批准：

| 文件 | 已有变化 | 状态 |
|---|---|---|
| `default.custom.yaml` | GUI 生成时间变动；方案列表为 easy_en、flyhe_fast、flypy_xhfast，移除 xhup 和小鹤双拼 | 保留当前选择，不擅自恢复旧列表 |
| `lua/easy_en_enhance.lua` | 加入 WhatsApp 和常用缩写还原，例如 ive → I've、dont → don't | 尚待真实 Lua 测试及输入法验证 |
| `lua/easy_en_rank.lua` | 去撇号查词频、提升缩写完全匹配候选 | 尚待排序回归验证 |

最后一次可读用户问题是“那 I've 这种应该怎么打呢”。Claude 解释了打 `ive`、
`im`、`dont` 等编码，并提出缩写排序及连输还原的改法；可读会话中未见用户随后确认，
会话以用户中断结束。因此不能把工作区内的缩写改动认作已经完成并验收。

## 已发现的完善事项

1. **更新脚本落后于当前配置。** 它仍从 fast-xhup 复制 Easy English schema、dict 和 Lua，
   生成缺少词频排序、纯 Lua 拆词及标点处理的 easy_en.custom，并重建全局方案列表。
   当前 README 的“可重复执行”不能理解为会保留全部个人定制。修复前不要直接重跑。
2. **脚本覆盖保护发生得太晚。** 复制后才检查与 crane 的文件冲突；检查失败时目标可能已被修改。
3. **脚本会递归复制上游用户数据库。** 维护更新流程时需考虑现有个人词库的保护。
4. **英文增强缺少仓库内的真实 Lua 回归检查。** 历史会话使用 Node 复刻算法验证，
   且明确说过没有部署，不能由此断言输入法中已经生效。
5. **拆词是词频启发式。** 历史示例 `saidhellotome` 可能拆成 `said hello tome`；
   不具备语境理解能力，应保留单词完整性及常见句子回归案例。
6. **缩写歧义。** `its`、`id`、`ill`、`were`、`well`、`hell` 本身可为合法词，
   不应无条件替换为带撇号形式；需要验证大小写、完整单词和拆词候选优先级。
7. README 和 9 月整合报告描述的是早期状态，需要按验证后的实际行为更新。

建议顺序：收尾英文缩写及回归验证 → 修复上游更新的覆盖保护 → 更新使用说明。
具体范围仍需结合用户当前问题确定。

## 旧记忆的适用边界

- Rime 方案及词典放在用户目录根部；子目录中的方案不会自动被发现。
  `additional_plugin_directories` 不能作为本项目的方案加载方案。
- Git Bash 调用 WeaselDeployer 时，MSYS 会转换 `/deploy`，需要关闭参数路径转换。
  旧记忆提到部署成功可能返回 1，应以日志中的成功/失败统计判断。
- 旧项目曾要求直接辅码四码连打，对应 `derive|/||`；当前仓库该行仍注释。
  这属于跨阶段需求差异，不能直接覆盖现在的快拼配置。
- 安装目录版本号、当前启用方案及运行情况都属于可变状态，需要现场核对。

## 本次接续已完成的检查

- 阅读项目 Claude 会话、旧 Rime 记忆、最近提交和当前未提交差异。
- 核对英文方案挂载关系、标点处理和更新脚本的覆盖路径。
- 运行 `git diff --check`，接手时已有差异没有报告空白错误。
- 尚未进行真实 Lua 测试、重新部署、提交或推送。

## 2026-10-22 英文缩写候选排查

用户截图中 `ive` 首候选为 `ive`、`im` 首候选为 `IM`。源词典包含
`I've → ive` 和 `I'm → im`；新启动的本机 Rime 引擎加载当前 Lua 后，
两者均为第一候选。已有排序代码修改晚于之前的部署，问题与运行中的旧代码一致。

新增 `tools/test-easy-en.py`，使用 Python 标准库 ctypes 调用本机 `rime.dll`，
在 `build/` 内独立临时用户目录测试，不使用真实用户数据库。
六项第一候选检查通过：ive → I've、im → I'm、dont → don't、cant → can't，
以及 its、hello 保持正常；均保留英文选词的尾部空格。

运行方式：`python tools/test-easy-en.py --rime-dir "C:/Program Files/Rime/weasel-0.17.4"`。
路径随本机安装版本调整，需要先有小狼毫部署生成的 easy_en build 文件。
本轮未修改现有生产 Lua；已调用小狼毫重新部署以加载现有缩写排序。

额外诊断发现：连续输入 `ivebeenthere` 仍可能先出现词典拼接候选而非预期拆词，
这是与单独输入 ive/im 不同的待办，六项检查不覆盖连续句子拆词。
