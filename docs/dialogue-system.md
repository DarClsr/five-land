# 对话系统规格

## 1. 定位

对话系统的数据与运行规格。数据驱动（Resource/JSON），场景只挂载运行器，不写死台词——五境对话量会爆炸，写死必返工（AGENTS.md「避免把玩法逻辑写进 UI 或场景节点」的同一原则）。序章 P2 实现最小可用版（顺序对话 + 单选项分支），完整版（条件、事件、多选项）随支线扩展。

## 2. 数据结构

### 2.1 DialogueLine（单行）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | StringName | 唯一行 ID，如 `fl_p01_ali_01` |
| `speaker` | StringName | 角色 ID，引用 `character-visual-guide.md`（`wuyang` / `ali` / `narrator` / `residue`） |
| `text` | String | 台词文本 |
| `tone` | String | 语气标签：`self`（无央自己）/ `ali`（像阿砾）/ `shenxi`（像沈汐）…用于无央模仿染色（narrative-differentiation 第 7 节） |
| `conditions` | Array[String] | 显示条件键（如 `evidence_smuggled_blade`），为空则无条件 |
| `next` | StringName | 下一行 ID；为空表示行结束（跳选项或关闭） |
| `events` | Array[String] | 行播完触发的事件键（`unlock_stance_water` / `save_checkpoint` / `play_zone_change`…） |

### 2.2 DialogueOption（选项）

| 字段 | 类型 | 说明 |
|---|---|---|
| `label` | String | 选项文本（污染选项带 `[corrupt]` 前缀，ui-spec 腐化色标记） |
| `next` | StringName | 跳转行 |
| `effects` | Dictionary | 计分/状态效果，键用 ending-scorecard 存档键：`{"cycle_points": 1}` |
| `conditions` | Array[String] | 显示条件（证据板进度、纹路等级等） |

### 2.3 文件组织

- 每个场景一个 JSON：`data/dialogues/fl_p01.json`（序章）/ `data/dialogues/mu_p01.json`（木境）。
- 运行时由 `DialogRunner`（节点）加载：`load("res://data/dialogues/fl_p01.json")` 解析为行字典，按 `id` 顺序推进。
- 场景引用：对话触发区/角色节点持有 `dialogue_file` 导出字段，不持有具体台词。

## 3. 运行规则

- 推进：确认键前进；有 `next` 则播下一行，无则检查选项。
- 选项：`conditions` 全部满足才显示；无满足选项时对话结束。
- 暂停：对话期间游戏暂停（沿用序章「对话期间输入」验收项，xumen-prologue-quests 第 7 节），镜头锁定或轻微推拉（ui-spec 演出镜头）。
- 语气染色：无央行若带 `tone`，选项标签按对应角色语气改写（写作层，不改语义与结果）。
- 跳过：已看过的对话可长按跳过（设置项）。

## 4. 序章示例（FL-P01 阿砾首对话节选）

```json
[
  {
    "id": "fl_p01_ali_01",
    "speaker": "ali",
    "text": "墟门只接死人。你从下面走上来，算哪一种？",
    "tone": "self",
    "next": "fl_p01_wu_01"
  },
  {
    "id": "fl_p01_wu_01",
    "speaker": "wuyang",
    "text": "我不知道。",
    "tone": "self",
    "next": "fl_p01_ali_02"
  },
  {
    "id": "fl_p01_ali_02",
    "speaker": "ali",
    "text": "那就先活着，名字以后再找。",
    "tone": "self",
    "options": [
      {
        "label": "问：命契是什么？",
        "next": "fl_p01_opt_life_contract"
      },
      {
        "label": "问：你为什么帮我？",
        "next": "fl_p01_opt_why"
      }
    ]
  }
]
```

选项支线行只补信息，不改任务结果（xumen-prologue-quests FL-P01 玩家选择规则）。

## 5. 与既有规格衔接

- 表现：ui-spec 对话窗（底部纸卷、说话人名牌、语气染色）。
- 条件键来源：证据板进度（quest-structure-differentiation 4.2）、纹路等级（corruption-system）、任务步骤（FL-P00 状态键）。
- 事件键来源：combat-narrative-fusion（`unlock_stance_water` 对应 FL-P02）、xumen-prologue-quests（任务推进、检查点解锁）。
- 角色 ID 表：见 glossary 命名规范与 character-visual-guide。

## 6. 验收标准

- [ ] 序章全部对话（FL-P00~P05 + FL-S01/S02）以 JSON 数据驱动，场景无硬编码台词。
- [ ] 选项条件（证据/纹路/任务步骤）可正确过滤显示。
- [ ] 无央 `tone` 染色只改表达不改结果。
- [ ] 对话期间输入与暂停规则符合序章验收项。
- [ ] 新场景对话文件命名遵循 `data/dialogues/<章节>_<任务>.json`。
