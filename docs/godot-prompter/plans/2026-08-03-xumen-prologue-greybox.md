# 墟门序章灰盒关卡计划

## 目标

建立一条可从归墟出口连续走到负碑兽场地的 HD-2D 灰盒路线，验证五个序章区域的空间顺序、镜头可读性与战斗尺度。

## 方案选择

采用独立的 `xumen_prologue_greybox.tscn` 作为序章组合根，保留 `hd2d_test.tscn` 用于战斗回归。灰盒几何由专用建造器生成基础箱体、碰撞和区域地标，不与任务或战斗逻辑混合。

## 主路线

```text
深渊出口（0，8）
    ↓ 倒悬碑桥
墟门（0，-6）
    ↓ 送葬道
战斗遭遇（0，-18）
    ↓ 断墙坡道
封印庭院（0，-31）
    ↓ 墓门
负碑兽场地（0，-45）
```

主路线始终沿世界 `-Z` 方向推进，各区域以不同平面尺度和左右地标建立轮廓，避免仅依赖颜色识别。

## 场景树

```text
XumenPrologueGreybox (Node3D)
├── GreyboxRoute (Node3D)
├── Entities (Node3D)
│   ├── Player (CharacterBody3D)
│   └── BurialRoadEnemy (CharacterBody3D)
├── Triggers (Node3D)
│   ├── DeepExit (Area3D)
│   ├── XumenGate (Area3D)
│   ├── BurialRoad (Area3D)
│   ├── SealCourtyard (Area3D)
│   └── BossArena (Area3D)
├── FollowCameraRig (Node3D)
├── WorldEnvironment
├── MoonKey
└── HUD (CanvasLayer)
```

## 数据与通信

- 关卡根节点持有玩家、敌人、镜头和 HUD 引用。
- 关卡根节点向镜头和敌人注入玩家引用。
- `Area3D.body_entered` 向关卡根节点上报区域进入事件，根节点更新区域名与单一主目标。
- 路线建造器只拥有静态网格、材质与碰撞，不知道玩家或任务状态。
- 本阶段不持久化区域进度；任务系统在下一个 P2 任务中接入。

## 任务

- [x] 建立可碰撞的五区域灰盒路线与空间地标。
  Skills: `scene-organization`, `3d-essentials`, `physics-system`
- [x] 建立固定倾角、平滑跟随的 HD-2D 镜头。
  Skills: `camera-system`, `physics-system`
- [x] 接入玩家、送葬道训练敌人和区域目标 HUD。
  Skills: `scene-organization`, `hud-system`, `ai-navigation`
- [x] 增加区域顺序、碰撞、镜头注入与遭遇注入自检。
  Skills: `godot-testing`, `godot-code-review`
- [x] 通过 Godot MCP 运行、日志和 1280×720 截图验收。
  Skills: `godot-testing`, `godot-code-review`
