# 无央行走动画接入规格

## 范围

将已验收的右前行走 spritesheet 接入现有 `AnimatedSprite3D`。角色有移动输入时播放 `walk`，停止时恢复 `idle`；左右移动继续使用现有 `flip_h`。

本次不生成新素材，不实现八方向、攻击动画、动画状态机或额外节点。

## 实现

- 将修正后的 8 帧、640×640 单元 spritesheet 放入 `assets/characters/wuyang/walk/`。
- 在 `scenes/actors/player.tscn` 的现有 `SpriteFrames` 中增加 10 FPS 循环 `walk`。
- 在 `player_controller.gd` 中根据实际移动方向选择 `walk` 或 `idle`，仅在动画变化时调用 `play()`。
- 保持 `Visual.position.y = 0.55`，不改变碰撞体、速度或战斗逻辑。

## 验收

测试须确认 `walk` 存在且为 8 帧，并确认非零移动选择 `walk`、零移动选择 `idle`。全部 Godot 自检和主场景烟雾检查通过后，以 1280×720 画面确认动画推进、脚底不浮空。
