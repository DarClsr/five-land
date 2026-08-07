# 序章场景与人物优化清单

2026-08-07 修复复核。基于 Godot 4.7.1 冒烟运行、`scripts/run_tests.ps1` 全量自检和 1280×720 实机截图。本文区分已完成的工程修复与仍属于玩法制作范围的后续内容。

## 已完成

### 1. 八方向走路动画

- 新增 `assets/characters/wuyang/pixel/wuyang_walk_8x8_v1.png`，规格为 8 个方向 × 8 帧、每格 128×128。
- `DirectionalSpriteFrames.build_with_walk()` 负责构建单帧待机与八帧行走动画。
- 角色 Shader 支持图集 UV 切换，轮廓光、环境染色与武器辉光可作用于每一帧。

### 2. 石板材质与 SSR

- 当前美术方向为高粗糙度像素岩石，不再恢复写实湿石镜面。
- 已关闭与高粗糙度材质冲突的 SSR，保留 SSAO 接触阴影。
- 石板维持 `0.92+` 粗糙度，避免重新出现塑料感。

### 3. 调色收敛

- 移除 `xumen_cinematic_lut.tres` 与 Environment Adjustment 层。
- 当前只保留 AgX 色调映射与 HD-2D Posterize 后处理，避免三层调色叠加。

### 4. 色温与阴影覆盖

- 冷色环境光与暖灰雾维持“暖灯火、冷暗部”关系。
- 平行光阴影距离由 55m 提升到 80m，覆盖完整序章路线。

### 5. 石板 Draw Call 与材质实例

- 石板路由逐块 `MeshInstance3D` 改为按 5 档色调 × 3 档光泽分组的 `MultiMeshInstance3D`。
- 世界坐标贴图材质缓存不再把随机尺寸写入 key。
- 岩堆不再逐块 `duplicate()` 材质，改为三档共享材质。
- 路线和氛围石材逻辑统一到 `scripts/world/hd2d_material_library.gd`。

### 6. 灯笼运行开销

- 16 盏灯每 0.2 秒按相机距离更新可见性，仅激活 18m 范围内的灯光。
- 屏幕外灯光不再执行逐帧呼吸更新。
- 非归墟出口灯光关闭体积雾能量，近景主灯保留受控体积光。

### 7. 敌人血条

- 删除每个敌人的 `SubViewport + ProgressBar`。
- 改为 `Sprite3D + world_health_bar.gdshader`，通过单一 `progress` 参数更新。

### 8. 局部 Hit Stop

- 不再使用 `get_tree().paused`。
- 命中停顿只冻结玩家与受击敌人的 `_process()`/`_physics_process()`，雾、粒子、灯光和相机继续运行。

### 9. 无重载重试

- `retry` 不再调用 `reload_current_scene()`。
- 现在原地恢复玩家和敌人的 Transform、生命、碰撞、状态机与 HUD，不重建程序化场景。

### 10. 资产导入管线

- Godot 已完成新 PNG、角色图集与 Shader 的导入，运行时资源均有 `.import`。
- `outputs/.gdignore` 阻止 AI 生成中间文件进入 Godot 导入扫描。
- `.blend` 当前可以成功导入；后续仍建议将纯制作源文件迁移到项目外的 DCC 源素材仓库。

### 11. 导出安全的贴图加载

- 玩家方向贴图已由 `Image.load_from_file()` 改为 `load()`。
- 地形源贴图改为 Godot 导入资源，不再在运行时直接读取原始 PNG。
- 冒烟运行已无“will not work on export”警告。

## 同步清理

- 删除空实现 `_add_label()` 及其无效调用，区域名称统一由 HUD/触发器展示。
- 粒子软点纹理由每个发射器重复生成改为场景级缓存。
- 重复石材构建逻辑抽成 `HD2DMaterialLibrary`。
- 新增局部 Hit Stop、无重载重试、Shader 血条、八方向八帧动画测试。

## 仍待玩法制作

以下内容不再是渲染或性能阻塞，但仍属于序章垂直切片的玩法任务：

1. 负碑兽正式模型、技能状态机、锁场与首领战流程。
2. 对话系统、任务步骤与墟门机关。
3. 训练敌人的正式待机、受击、攻击和死亡美术帧。
4. 峡谷岩壁进一步合并为 ArrayMesh/MultiMesh；当前已共享材质，但节点数量仍可继续降低。

## 验收命令

```powershell
godot --headless --path . --quit-after 3
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
git diff --check
```
