# 近战训练敌人与战斗手感计划

## 目标

把当前静态接触伤害敌人升级为可追击、有明确攻击前摇和受击反馈的近战训练敌人，用于验证移动、闪避、架势切换与克制手感。

## 状态机

```text
IDLE ──发现玩家──> CHASE ──进入攻击距离──> ATTACK
 ^                    ^                         │
 │                    └────攻击后摇结束────────┘
 │
 └──玩家脱离范围

任意非死亡状态 ──受击──> HURT ──硬直结束──> CHASE
任意状态 ──生命归零──> DEAD
```

`ATTACK` 内部分为 `WINDUP`、`ACTIVE`、`RECOVERY` 三个阶段，攻击区只在 `ACTIVE` 开启。

## 场景结构

```text
TrainingEnemy (CharacterBody3D)
├── Visual (Sprite3D)
├── CollisionShape3D
├── HealthComponent
├── HurtboxComponent
├── ContactHitbox
├── ElementComponent
├── AttackTell (Sprite3D)
├── EnemyHealthViewport (SubViewport)
│   └── HealthBar (ProgressBar)
└── EnemyHealthSprite (Sprite3D)
```

## 信号与数据流

1. 主场景把玩家引用注入训练敌人。
2. 敌人根据水平距离切换待机、追击与攻击状态。
3. 攻击有效帧开启 `HitboxComponent`，命中时传递伤害、方向与击退强度。
4. `HurtboxComponent` 发出受击信号；角色控制器负责硬直、击退与闪白。
5. `HealthComponent.health_changed` 驱动世界空间生命条，不逐帧轮询。
6. 玩家命中后由主场景触发极短命中停顿，Timer 使用始终处理模式恢复游戏。

## 任务

- [x] 扩展命中与受击组件，携带击退方向和强度。
  Skills: `component-system`, `physics-system`
- [x] 为玩家加入受击击退和闪白反馈。
  Skills: `player-controller`, `tween-animation`
- [x] 实现训练敌人 FSM、直接趋近与三阶段近战攻击。
  Skills: `state-machine`, `ai-navigation`, `physics-system`
- [x] 加入敌人头顶生命条、攻击提示和命中停顿。
  Skills: `hud-system`, `tween-animation`
- [x] 增加状态、攻击窗口和击退自检，并通过 Godot MCP 验收。
  Skills: `godot-testing`, `godot-code-review`
