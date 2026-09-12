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

# 无头测试（27 项：逻辑冒烟 + 物理集成）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_smoke.gd
```

## 操作

| 行为 | 键位 |
| --- | --- |
| 左右移动 | A / D 或 ← / → |
| 跳跃 | Space |
| 攻击 | J |
| 重置场景 | R |

## 手感参数

全部集中在 `scripts/game_params.gd`：移动速度/加速度/摩擦、跳跃初速度、重力、
攻击三段窗口（startup 0.08s / active 0.12s / recovery 0.22s，按物理帧取整、
60fps 下实际约 0.08/0.13/0.23s）、伤害、击退、硬直、闪白时长、木桩血量与摩擦、
舞台尺寸，以及所有颜色。
改参数只动这一个文件；角色共用同一套形状结构（`native_shapes.gd`），只换颜色。

攻击期间（地面）水平输入失效、不能跳跃、不能取消；active 阶段会在身前显示
半透明命中框，方便核对攻击范围。同一次出招对同一目标最多命中一次。

## MVP 验收对照

1. 启动即进训练场：主场景直配，无需额外配置。✅
2. 边界内稳定移动与跳跃、落地可预测：左右墙体约束 + 默认 CharacterBody2D 落地，测试覆盖。✅
3. 攻击范围与持续时间一致、远近命中正确：固定 hitbox 与窗口，测试覆盖远距不中/近距命中。✅
4. 木桩受击至少两种反馈：血条变化 + 闪白 + 击退位移。✅
5. 可连续攻击/移动/跳跃测试，R 重置后血量与站位恢复。✅
6. 全部视觉由原生 Polygon2D / draw_rect 绘制，无外部美术；颜色集中在参数文件。✅

## 已知限制（按规划暂不决策）

- 木桩血量归零后不会消失或重生，仍可继续受击（训练桩行为）。
- 只有一种招式，无防御、闪避、连招、AI、回合与计时。
- 空中可以出招（保留空中动量），无空中跳跃次数限制外的额外规则。
- 无音效、无屏幕震动、无 HUD（仅木桩头顶血条与左上角按键提示）。

## 目录结构

```
project.godot            输入映射、窗口 960x540、主场景
scripts/game_params.gd   全部可调参数（含颜色）
scripts/native_shapes.gd 原生形状绘制：矩形与共用角色结构
scripts/player.gd        玩家：移动/跳跃/朝向/攻击状态机
scripts/dummy.gd         木桩：受击（掉血/闪白/击退）与头顶血条
scripts/main.gd          训练场搭建、生成角色、重置
scenes/*.tscn            main / player / dummy 三个场景
tests/test_smoke.gd      无头测试（SceneTree 脚本）
```
