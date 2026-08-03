# 技术参考与借鉴边界

本项目使用 Godot 4 原生能力自行实现玩法。下列项目只作为表现、战斗节奏或数据组织参考；除非另有说明，不复制其代码、场景树或资源，也不把它们作为运行时依赖。

## 参考项目

| 参考源 | 借鉴内容 | 当前落地 | 边界 |
| --- | --- | --- | --- |
| Meowa HD-2D 表现模板（本地参考） | `Sprite3D` Billboard、固定倾角与低视野角构图、景深、灯光、雾和环境调试方式 | `scenes/hd2d_test.tscn` 的相机、灯光、雾；`scenes/actors/player.tscn` 的 Billboard 临时角色 | 未引入模板场景树或脚本；正式素材仍通过 Meowa CLI 与 `game-assets` 生成并单独验收 |
| [Cairnfall](https://github.com/euuuuuuan/cairnfall-public)（Apache-2.0） | 攻击预警、闪避窗口、Boss 多阶段节奏 | 训练假人的橙色预警与可闪避反击；Boss 节奏尚未实现 | 不导入其角色、关卡、AI 或战斗代码 |
| [Godot ARPG Kit](https://github.com/ClarkWain/godot-arpg-kit)（MIT） | `Resource` 驱动的数据设计、组件拆分、可运行测试 | `AttackData`、`HealthComponent`、`Hitbox3D`、`Hurtbox3D` 与 `tests/combat_foundation_test.gd` | 仅参考组织方式；当前 3D 战斗组件为本项目原生实现 |

## Godot 官方基础

实际运行依赖来自 Godot 4 官方 API：

- [`Resource`](https://docs.godotengine.org/en/stable/classes/class_resource.html)：保存攻击与后续五行数据。
- [`Area3D`](https://docs.godotengine.org/en/stable/classes/class_area3d.html)：实现命中盒与受击盒重叠检测。
- [`AnimationPlayer`](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)：播放表现动画，不承担伤害时序判定。
- [信号](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)：解耦生命变化、受伤与死亡处理。
- [`Sprite3D`](https://docs.godotengine.org/en/stable/classes/class_sprite3d.html) 与 [`Environment`](https://docs.godotengine.org/en/stable/classes/class_environment.html)：构成当前 HD-2D 临时表现。

## 使用原则

新增借鉴时必须记录来源、许可证、借鉴点和落地文件。复制第三方代码或素材前需单独确认许可证与署名要求；仅观察设计思路时，也要明确标注“参考而非依赖”。
