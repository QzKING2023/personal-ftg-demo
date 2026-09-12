# FTG Demo

用 Godot 4.5 原生形状绘制的横向格斗手感验证 Demo：单训练场、一名玩家、一个木桩。
启动即进入训练场，可移动、跳跃、出招、命中木桩观察受击反馈，随时重置。

## 运行

1. 用 Godot 4.5 打开本目录的 `project.godot`（首次打开会自动导入）。
2. 按 F5（运行项目）即可，主场景已设为 `res://scenes/main.tscn`。

命令行方式（无渲染验证）：

```bash
# 编辑器导入 + 校验资源
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --editor --quit

# 主场景无头运行若干帧（冒烟）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --quit-after 300

# 战斗会话 seam 测试（66 项：逐帧输入 → 可观察状态与事件）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_combat_session.gd

# 训练场集成测试（28 项：注入输入 + 真实物理帧）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_smoke.gd
```

## 操作

| 行为 | 键位 |
| --- | --- |
| 左右移动 | A / D 或 ← / → |
| 跳跃 | Space |
| 攻击 | J |
| 重置场景 | R |

## 架构：战斗会话

战斗结算集中在确定性会话（`scripts/combat/`），按物理帧逐步结算；训练场只负责
输入适配、呈现与重置（ADR-0001）。每个物理帧严格按以下顺序结算：

```
输入 → 命中判定 → 受击应用 → 运动/落地/自然受身 → 取消判定 → 消费缓存
```

- `combat_session.gd`：`CombatSession.step(FrameInput)` 返回本帧战斗事件，
  并维护可观察的玩家状态（位置/朝向/招式阶段/是否落地）与木桩状态
  （位置/生命值/受击状态/剩余硬直帧）。取消与输入缓存阶段是后续连段
  issue 的管线占位，当前无操作。
- `move_data.gd`：招式数据（startup/active/recovery 帧数、伤害、命中框、
  击退与硬直），可配置、可替换；`FrameInput`/`CombatEvent` 为单帧输入与事件。
- `main.gd` 每个物理帧读取输入喂给会话，再把会话状态写入 `player.gd`/`dummy.gd`
  两个纯呈现层；命中事件驱动木桩闪白，右上角显示木桩生命值与受击状态。
- 碰撞（地面、墙体、身体不互相穿透）由会话按几何结算，不再依赖物理服务器。

## 手感参数

全部集中在 `scripts/game_params.gd`：移动速度/加速度/摩擦、跳跃初速度、重力、
攻击三段窗口（startup 5 帧 / active 7 帧 / recovery 13 帧，60 物理帧/秒）、
伤害、击退、硬直（12 帧）、闪白时长、木桩血量与摩擦、舞台尺寸，以及所有颜色。
招式窗口与伤害在 `MoveData` 中按招式配置，默认值取自 GameParams；改帧数/伤害
不需要动结算逻辑。角色共用同一套形状结构（`native_shapes.gd`），只换颜色。

攻击期间（地面）水平输入失效、不能跳跃、不能取消；active 阶段会在身前显示
半透明命中框，方便核对攻击范围。同一次出招对同一目标最多命中一次。

## MVP 验收对照

1. 启动即进训练场：主场景直配，无需额外配置。✅
2. 边界内稳定移动与跳跃、落地可预测：会话结算墙体约束与落地，测试覆盖。✅
3. 攻击范围与持续时间一致、远近命中正确：固定 hitbox 与帧窗口，测试覆盖远距不中/近距命中。✅
4. 木桩受击至少两种反馈：血条变化 + 闪白 + 击退位移 + 状态显示。✅
5. 可连续攻击/移动/跳跃测试，R 重置后血量与站位恢复。✅
6. 全部视觉由原生 Polygon2D / draw_rect 绘制，无外部美术；颜色集中在参数文件。✅

## 已知限制（按规划暂不决策）

- 木桩血量归零后不会消失或重生，仍可继续受击（训练桩行为）。
- 只有一种招式，无输入缓存、取消、连招、防御、闪避、AI、回合与计时
  （输入缓存与命中确认取消见后续 issue）。
- 空中可以出招（保留空中动量），无空中跳跃次数限制外的额外规则。
- 无音效、无屏幕震动（HUD 有木桩头顶血条、左上角按键提示与右上角状态显示）。

## 目录结构

```
project.godot                 输入映射、窗口 960x540、主场景
scripts/game_params.gd        全部可调参数（含颜色）
scripts/native_shapes.gd      原生形状绘制：矩形与共用角色结构
scripts/combat/frame_input.gd     单物理帧输入快照
scripts/combat/move_data.gd       招式数据（窗口/伤害/命中框/击退/硬直）
scripts/combat/combat_event.gd    单帧战斗事件（命中/自然受身）
scripts/combat/combat_session.gd  确定性战斗会话（逐帧结算 seam）
scripts/player.gd             玩家呈现层（会话状态 → 节点显示）
scripts/dummy.gd              木桩呈现层（血条/闪白/位置）
scripts/main.gd               训练场：输入适配、会话驱动、反馈与重置
scenes/*.tscn                 main / player / dummy 三个场景
tests/test_combat_session.gd  战斗会话 seam 测试（逐帧输入驱动）
tests/test_smoke.gd           训练场集成测试（SceneTree 脚本）
```
