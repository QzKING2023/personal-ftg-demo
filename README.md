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

# 战斗会话 seam 测试（401 项：逐帧输入 → 可观察状态与事件）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_combat_session.gd

# 训练场集成测试（85 项：注入输入 + 真实物理帧）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_smoke.gd

# Combo Solver 测试（112 项：开头会打印默认招式表的可读验证报告）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_combo_solver.gd

# 共享招式表测试（issue 11：manifest 加载、整表校验、双端共享与拒绝）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_move_table.gd

# 搓招与空中运动诊断回路（逐帧打印物理键/相对方向/面向/识别招式/缓存/取消/命中；
# 退出码非 0 = 仍有未修复症状，当前红色项全部为待定的地面面向规则，见
# .scratch/ftg-combat-foundation/diagnosis.md）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/diagnose_inputs.gd
```

## 操作

| 行为 | 键位 |
| --- | --- |
| 左右移动 | A / D 或 ← / → |
| 下方向（搓招用） | S / ↓ |
| 跳跃 | Space |
| 动作 A / B / C / D | U / I / K / J |
| 方向派生 236+C / 214+D | 依次输入方向序列（数字按面向折算）后按动作键 C（K）/ D（J） |
| 重置场景 | R |

## 架构：战斗会话

战斗结算集中在确定性会话（`scripts/combat/`），按物理帧逐步结算；训练场只负责
输入适配、呈现与重置（ADR-0001）。每个物理帧严格按以下顺序结算：

```
输入 → 命中判定 → 受击应用 → 运动/落地/自然受身 → 取消判定 → 消费缓存
```

命中帧完整结算后进入 8 帧 Hitstop（issue 14）：冻结帧内双方动作、位置、速度、
受击/落地/受身计时暂停，物理帧号照常递增；输入仍采样记录（动作键缓存、方向
历史照常写入，最新覆盖旧输入），但不启动、取消或消费动作。缓存、方向窗口与
取消窗口的年龄只按正常战斗帧增加——停顿中按下的输入从恢复首个正常帧起算
年龄 0，恢复首帧才消费；命中确认取消窗口为正常帧年龄 0–8（含两端），挥空
永不获得资格。`CombatEvent` 以 `HITSTOP_STARTED/HITSTOP_ENDED` 标出停顿边界，
诊断快照暴露停顿剩余、缓存年龄、取消龄/资格与实际消费结果。

- `combat_session.gd`：`CombatSession.step(FrameInput)` 返回本帧战斗事件，
  并维护可观察的玩家状态（位置/朝向/招式阶段/是否落地）与木桩状态
  （位置/生命值/受击状态/剩余硬直帧）。
- 招式数据是共享的本地类型化资源（issue 11）：`data/moves/*.tres` 每招一份
  `MoveData`，由 `data/move_manifest.tres` 统一引用；`move_table.gd` 的
  `MoveTable` 负责加载与整表校验——缺核心字段、类型错误、负帧数、未知枚举、
  非法方向谓词、矛盾字段组合或跨招式非法引用都会整表拒绝，错误按
  「资源来源｜招式 id｜字段｜原因」定位。训练场与 Combo Solver 只读同一份
  已校验 manifest；非法表使两处保持拒绝并显示同一原因，不跳过招式、不静默
  修正、也不回退旧 GameParams 数值。设计者编辑 `.tres` 后两处行为同步变化；
  资源缓存按路径驻留，改完文件需重新运行项目。
- `main.gd` 每个物理帧读取输入喂给会话，再把会话状态写入 `player.gd`/`dummy.gd`
  两个纯呈现层；命中事件驱动木桩闪白，右上角显示木桩生命值与受击状态。
- 碰撞（地面、墙体、身体不互相穿透）由会话按几何结算，不再依赖物理服务器。
- `combo_solver.gd`：开发期 Combo Solver——只读招式数据，用一次性 CombatSession
  探针验证命中确认接续（前摇、等待、取消窗口、木桩硬直、地面/空中姿态、方向派生、
  jump cancel 与落地接缝），枚举可读路线，并以逐圈模拟加木桩时序状态重现证明有效
  循环（ADR-0002）。报告帧号与年龄按正常战斗帧计：Hitstop 冻结物理帧不消耗窗口，
  回放输入表时以空输入跳过冻结帧。它不修改运行时战斗状态，不设命中数/时长上限，
  也不证明空间/中立/碰撞连接；空中段只能经配置的 jump cancel 进入，玩家滞空与
  木桩浮空作为有限资源不会被当作可自动续期。设计者直接跑 Solver 测试即可看到
  默认表的可读报告。

## 手感参数

非招式参数（舞台、移动、跳跃、重力、木桩、HUD 与全部颜色）集中在
`scripts/game_params.gd`。招式窗口/伤害/属性/绑定/优先级等自 issue 11 起是
共享资源数据：`data/moves/*.tres`（冻结首版数值见规格）+ `data/move_manifest.tres`；
`GameParams` 中的 `MOVE_*` 常量仅作测试断言基线，运行时不读取。改招式帧数/伤害
直接编辑对应 `.tres`，训练场与 Solver 同步生效；改完需重新运行项目（资源缓存
按路径驻留）。角色共用同一套形状结构（`native_shapes.gd`），只换颜色。

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
- 停顿内的 jump 按下尚无独立缓存槽（Space 在 Hitstop 内无效，恢复后取消窗口
  仍按正常帧开放——跳跃输入槽与 pre-jump 见后续 issue）；防御、投技、冲刺、
  蹲防、AI、回合与计时均未实现。
- 空中可以出招（保留空中动量），无空中跳跃次数限制外的额外规则。
- 无音效、无屏幕震动（HUD 有木桩头顶血条、左上角按键提示、右上角状态显示与
  左下角诊断行——面向/方向序列/识别招式/缓存剩余/停顿剩余/取消龄与资格）。

## 目录结构

```
project.godot                 输入映射、窗口 960x540、主场景
data/moves/*.tres             共享招式资源（每招一份 MoveData，冻结首版数值）
data/move_manifest.tres       招式表清单（统一引用，训练场与 Solver 共用）
scripts/game_params.gd        非招式可调参数（含颜色）；MOVE_* 仅测试基线
scripts/native_shapes.gd      原生形状绘制：矩形与共用角色结构
scripts/combat/frame_input.gd     单物理帧输入快照
scripts/combat/move_data.gd       招式数据 schema（类型化 Resource）
scripts/combat/move_manifest.gd   招式清单资源（引用每招一份 .tres）
scripts/combat/move_table.gd      共享表加载与整表校验（非法表整表拒绝）
scripts/combat/combat_event.gd    单帧战斗事件（命中/自然受身）
scripts/combat/combat_session.gd  确定性战斗会话（逐帧结算 seam）
scripts/combat/combo_solver.gd    开发期 Combo Solver（接续验证与循环报告）
scripts/player.gd             玩家呈现层（会话状态 → 节点显示）
scripts/dummy.gd              木桩呈现层（血条/闪白/位置）
scripts/main.gd               训练场：输入适配、会话驱动、反馈与重置
scenes/*.tscn                 main / player / dummy 三个场景
tests/test_move_table.gd      共享招式表 seam 测试（加载/校验/双端拒绝）
tests/test_combat_session.gd  战斗会话 seam 测试（逐帧输入驱动）
tests/test_smoke.gd           训练场集成测试（SceneTree 脚本）
tests/test_combo_solver.gd    Combo Solver 测试（含可读报告打印）
tests/diagnose_inputs.gd      搓招与空中运动诊断回路（逐帧诊断记录与症状判定）
```
