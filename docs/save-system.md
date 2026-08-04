# 存档系统规格（序章最小版）

## 1. 定位

序章只实现单槽自动存档最小版；多存档与完整结局存档在「暂不开发」清单（TODO 底部）。本规格定义存档时机、内容与读档行为，状态键 schema 沿用 `ending-scorecard.md` 第 4 节。

## 2. 存档时机（自动）

| 时机 | 触发条件 | 说明 |
|---|---|---|
| 检查点激活 | 首次到达墟门检查点（`FL-P03` 后） | 写入检查点位置 |
| 任务完成 | 每个主线任务完成节点（`FL-P00`~`FL-P05` 完成时） | 写入 `prologue_step` |
| 关键选择 | 支线选择后（`FL-S01`/`FL-S02` 选择确认） | 写入 `side_*_choice` |
| 剧情演出前 | 首领战入场演出前（`FL-P04` 触发时） | 首领战失败重试的基准 |

- 手动存档：序章不提供（单槽自动 + 检查点即存档点）；驿站/检查点交互只做「确认复活点」不做「另存」。
- 死亡不写档：死亡重试从最近检查点或当前场次入口开始，不覆盖存档（避免「死亡惩罚存档」）。

## 3. 存档内容

```text
# 流程
prologue_step            # 当前任务步骤
prologue_complete        # bool
# 支线选择
side_blank_grave_choice / side_blank_grave_complete
side_downward_lantern_choice / side_downward_lantern_complete
# 位置
checkpoint_id            # DeepExit / XumenGate / BurialRoad / SealCourtyard / BossArena
# 状态
health                   # 当前生命
inventory                # 恢复物（镇魂膏/回潮露）数量
tutorial_seen            # 教学已看标志数组（见 tutorial-spec）
corruption_points        # 吸收累计（序章最多 +2）
evidence                 # 证据板条目（序章：走私刃具等）
# 存档元数据
save_time / play_time
```

## 4. 读档行为

- 启动游戏：读取最近自动档，恢复到检查点位置与任务状态。
- 死亡重试：不读档，从内存状态回退到最近检查点（当前场次进度按任务规则保留，如仪式进度/支线拾取状态，见 `xumen-prologue-return-paths.md` 第 6 节）。
- 读档一致性：读档后已观看的教学提示不重新强制暂停（`tutorial_seen` 保留）。

## 5. 存档格式与位置

- 格式：JSON，`user://save_0.json`（Godot `user://` 路径）。
- 写入方式：原子写（写临时文件后改名），防止中断损坏。
- 校验：存档头含版本号，版本不匹配时丢弃并提示新档。

## 6. 与既有系统衔接

- 状态键：与 `ending-scorecard.md` 第 4 节 schema 完全一致，序章字段是其子集。
- 检查点：`xumen-prologue-return-paths.md` 的检查点表即存档锚点。
- 教学标志：`tutorial_seen` 由 tutorial-spec 定义。
- 完整版（多存档、结局计分器持久化）在第二境完成后接入，schema 已预留。

## 7. 验收标准

- [ ] 序章全程无手动存档需求，自动存档覆盖全部关键节点。
- [ ] 死亡重试不覆盖存档、不重复发放奖励、不重复生成敌人。
- [ ] 读档后教学提示不重复强制暂停。
- [ ] 存档字段与 ending-scorecard schema 一致，版本号校验生效。
