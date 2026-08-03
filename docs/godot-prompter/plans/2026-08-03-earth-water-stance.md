# 土水架势与五行规则实现计划

## 目标

在现有最小战斗闭环上加入土、水双架势，让玩家通过 `Q` 切换元素，并让攻击伤害体现五行相生相克关系。

## 场景结构

```text
Player / TrainingEnemy
├── ElementComponent        当前元素与可用元素集合
├── HealthComponent
├── HurtboxComponent        暴露防御方元素
└── HitboxComponent         读取攻击方元素并结算伤害

HUD
├── StanceLabel             当前玩家架势
└── ElementFeedback         最近一次克制关系与实际伤害
```

## 信号与数据流

1. 玩家按 `Q`，`PlayerController` 调用 `ElementComponent.cycle_next()`。
2. `ElementComponent` 发出 `element_changed`，玩家更新占位颜色，HUD 更新架势标签。
3. `HitboxComponent` 命中 `HurtboxComponent`，读取双方元素并调用五行规则模块。
4. 实际伤害传入生命组件，命中组件发出 `hit_resolved`，HUD 显示倍率与关系。

## 任务

- [x] 创建五行规则、元素定义 Resource 与土/水数据。
  Skills: `resource-pattern`, `godot-testing`
- [x] 创建可复用 `ElementComponent` 并接入角色场景。
  Skills: `component-system`, `resource-pattern`
- [x] 为玩家加入 `Q` 架势切换，并让命中组件结算元素伤害。
  Skills: `input-handling`, `component-system`
- [x] 扩展 HUD 显示架势、敌方元素与克制反馈。
  Skills: `godot-ui`, `hud-system`
- [x] 添加五行规则和物理命中自检，使用 Godot MCP 验收。
  Skills: `godot-testing`, `godot-code-review`
