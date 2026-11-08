# FTG Demo

用 Godot 4.5 原生形状绘制的横向格斗手感验证 Demo：单训练场、一名玩家、一个木桩。
启动即进入训练场，可移动、冲刺、跳跃、出招、防御、投与命中木桩观察受击反馈，随时重置。

## 当前交付状态（2026-10-12）

这个 Demo 以训练场为载体，目标是把招式帧数据、输入识别、取消、受击、倒地、位置收益和反馈表现做成可复现、可审计的战斗规则。当前交付仍定位为训练场/MVP。

2026-10-12 阶段 G 已完成八个连段样本的功能交付。结论只覆盖声明条件、固定参考和有限工程采样；操作宽容度与真人体验待后续验收。

### 八样本路线功能交付

| 样本 | 路线 | 功能重点 |
| --- | --- | --- |
| R1-B | `5B > 5C > 236C(2) > 5[D], 5B > 6D > jB > jC > j214D, 5B > 214C~C` | 搬运长线，13 HIT，双换边，满足净推进 |
| R1-C | `5C > 236C(2) > 5[D], 5B > 6D > jB > jC > j214D, 5B > 214C~C` | 搬运长线，12 HIT，C 起手变体 |
| R2-B | `5B > 5C > 236C(2) > 5[D], 5B > 214C~C` | 抵墙短线，8 HIT，零换边 |
| R2-C | `5C > 236C(2) > 5[D], 5B > 214C~C` | 抵墙短线，7 HIT，C 起手变体 |
| R3-B | `5B > 5C > 236C(1) > 5D, 5B > 5C > 236C(1) > 5D, 5B > 2C` | 原版边两轮普通 D，10 HIT，零换边并自然倒地 |
| R3-C | `5C > 236C(1) > 5D, 5B > 5C > 236C(1) > 5D, 5B > 2C` | 原版边两轮普通 D，9 HIT，C 起手变体 |
| R4-G | `6A > jc > jC > j214D, 5B > 214C~C` | 对地六击，真实弹地、落地恢复后追击 |
| R4-A | `6A > jc > jC > j214D, 5B > 214C~C` | 下落对空六击，6 HIT，按接触档位选择参考节奏 |

### 三类证据如何解读

- **自动化窗口/功能回归**：`full-10` 覆盖脚本、CombatSession、Solver、固定输入重放、有限域/固定参考采样、八样本路线、倒地、换边、保位、净推进、负例、保存恢复和跨路线回归。结果为 **39 suites、4,239 assertions、0 failures、0 script errors**。这些结果证明声明域和固定参考下的确定性行为，不证明连续域或所有场景。
- **联合输入覆盖**：报告保留已有真实分母和代表点：R1/R2 长线 jC 单窗 1F、联合 **0/64**；R4-A 代表点联合 **64/128**；票据 01 另有 64 个向量。旧 C6 居中组 **256/256×8**、scan anchor 的 B **128/256** 与 C **192/256** 仍是代表性历史结果，且存在 b2 漏测；R3 本轮没有新增 256 组。D113 的 244/256 与 231/256 目标尚未完成，因此不能把这些结果写成完整联合输入鲁棒性。
- **真人体验**：2026-10-12 报告明确记载真人 playtest 尚未执行；[playtest 表](https://github.com/QzKING2023/personal-ftg-demo/blob/main/.scratch/ftg-combo-routes/acceptance/playtest.md) §11 为空，未填写尝试次数、成功数、手感或结论。操作宽容度、手感、成功率和可读性仍待真人验收，自动化不能替代真人。

### 证据与资料

- [连段路线功能交付报告](https://github.com/QzKING2023/personal-ftg-demo/blob/main/.scratch/ftg-combo-routes/acceptance/functional-report.md)
- [full-10 自动化汇总](https://github.com/QzKING2023/personal-ftg-demo/blob/main/.scratch/ftg-combo-routes/runs/full-10/summary.json)
- [八样本练习步骤与真人空记录表](https://github.com/QzKING2023/personal-ftg-demo/blob/main/.scratch/ftg-combo-routes/acceptance/playtest.md)
- [当前进度索引](https://github.com/QzKING2023/personal-ftg-demo/blob/main/.scratch/ftg-combo-routes/progress.md)
- [功能交付工作流](https://github.com/QzKING2023/personal-ftg-demo/blob/main/docs/combo-route-functional-delivery.md)
- [训练场操作与联合验收](https://github.com/QzKING2023/personal-ftg-demo/blob/main/docs/training-guide.md)
- [招式与行为数据](docs/move-data.md)
- [Solver 独立入口、帧表与空间范围](docs/solver-guide.md)
- [武器型刺客角色研究](docs/weapon-assassin-character-research.md)
- 推荐全量检查：`python tools/run_acceptance.py --sweep --output <新目录>`；`./tools/run_acceptance.ps1` 保留为兼容入口。

## 历史基线（2026-09-17）

早期训练场验收与修复记录仍保留，作为项目历史上下文：

- [历史联合验收报告](.scratch/ftg-combat-foundation/acceptance-2026-09-17/report.md)
- [蹲姿修复记录](.scratch/ftg-combat-foundation/crouch-2026-09-18/diagnosis.md)

这部分历史记录不作为 2026-10-12 八样本路线的当前指标，也不替代当前真人试玩记录。

## 运行

1. 用 Godot 4.5 打开本目录的 `project.godot`（首次打开会自动导入）。
2. 按 F5（运行项目）即可，主场景已设为 `res://scenes/main.tscn`。

命令行方式（无渲染验证）：

```bash
# 编辑器导入 + 校验资源
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --editor --quit

# 主场景无头运行若干帧（冒烟）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --quit-after 300

# 战斗会话 seam 测试（逐帧输入 → 可观察状态与事件）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_combat_session.gd

# 训练场集成测试（注入输入 + 真实物理帧）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_smoke.gd

# Combo Solver 测试（开头会打印默认招式表的可读验证报告）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_combo_solver.gd

# Combo Solver 入口/路线/循环/空间分层测试（issue 19–22：solve 入口与操作说明、
# 配置缺口与方向 variant、循环状态去重键与截断/未完成观测上报、timing/spatial 分层）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_solver_entry.gd
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_solver_route.gd
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_solver_cycles.gd
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_solver_spatial.gd

# 最终路线回放与联合验收（issue 23：Solver 输出在全新会话/训练场真实键盘中回放
# 地面、派生、jump cancel 与旧落地负例，打印逐条回放记录——面向/站位/逐帧输入/
# 命中帧/连段数/总伤害与 timing/spatial 分层标签）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_replay_acceptance.gd

# 共享招式表测试（issue 11：manifest 加载、整表校验、双端共享与拒绝）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/test_move_table.gd

# 搓招与空中运动诊断回路（逐帧打印物理键/相对方向/面向/识别招式/缓存/取消/命中；
# 退出码非 0 = 仍有未修复症状；本轮全部通过，历史红项见 diagnosis.md）
Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://tests/diagnose_inputs.gd
```

## 操作

| 行为 | 键位 |
| --- | --- |
| 左右移动 | A / D 或 ← / → |
| 下方向（蹲下/搓招用） | S / ↓ |
| 跳跃 | Space / ↑（与下方向同时按中和） |
| 动作 A / B / C / D | U / I / K / J |
| 方向派生 236+C / 214+D | 依次输入方向序列（数字按面向折算）后按动作键 C（K）/ D（J） |
| 前冲 / 后撤（66/44） | 双击 →/←（两次同向之间松开至少一帧） |
| 普通投（B+C 组合） | I+K 3 帧内先后按下（投距内成立，木桩拆投由测试请求驱动） |
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
  木桩浮空作为有限资源不会被当作可自动续期。报告区分 timing-valid 与可选
  spatial-valid（issue 22）：无空间数据时路线仅 timing-valid，固定接触位不构成
  空间证明；提供空间数据（SolverOptions.spatial）后在地面、左右镜像的
  48/64/80 px 三组身体中心距离上复验并附 spatial-valid，不搜索走位、中立、
  墙角、推挤、跨身或屏幕边界。设计者直接跑 Solver 测试即可看到默认表的可读报告。

## 手感参数

非招式参数（舞台、移动、跳跃、重力、木桩、HUD 与全部颜色）集中在
`scripts/game_params.gd`。招式窗口/伤害/属性/绑定/优先级等自 issue 11 起是
共享资源数据：`data/moves/*.tres`（冻结首版数值见规格）+ `data/move_manifest.tres`；
`GameParams` 中的 `MOVE_*` 常量仅作测试断言基线，运行时不读取。改招式帧数/伤害
直接编辑对应 `.tres`，训练场与 Solver 同步生效；改完需重新运行项目（资源缓存
按路径驻留）。角色共用同一套形状结构（`native_shapes.gd`），只换颜色。

地面出招期间水平输入失效；仅在配置允许、命中确认与窗口有效时可取消或 jump cancel。active 阶段会在身前显示
半透明命中框，方便核对攻击范围。同一次出招对同一目标最多命中一次。

## MVP 验收对照

1. 启动即进训练场：主场景直配，无需额外配置。✅
2. 边界内稳定移动与跳跃、落地可预测：会话结算墙体约束与落地，测试覆盖。✅
3. 攻击范围与持续时间一致、远近命中正确：固定 hitbox 与帧窗口，测试覆盖远距不中/近距命中。✅
4. 木桩受击至少两种反馈：血条变化 + 闪白 + 击退位移 + 状态显示。✅
5. 可连续攻击/移动/跳跃测试，R 重置后血量与站位恢复。✅
6. 全部视觉由原生 Polygon2D / draw_rect 绘制，无外部美术；颜色集中在参数文件。✅

## 已知限制（按规划暂不决策）

- 八样本证据来自声明保证域、固定参考和有限工程采样；连续域未采样部分、全部走位、墙边、跨身和中立场景仍未由本轮结果覆盖。
- Solver 的循环结果是实际搜索范围内的结果，不构成全域无循环证明。
- 木桩血量归零后不会消失或重生，仍可继续受击（训练桩行为）。
- 木桩无 AI、无回合计时与胜负流程；high-jump、二段跳与空中特殊追击窗口
  属首版范围外，未定义输入或参数。
- 空中可以出招（保留空中动量），无空中跳跃次数限制外的额外规则。
- 无音效、无屏幕震动（HUD 有木桩头顶血条、左上角按键提示、右上角状态显示与
  左下角诊断行——面向/姿态/冲刺剩余/方向序列/识别招式/缓存剩余/停顿剩余/
  取消龄与资格）。

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
tests/test_solver_entry.gd    Solver 正式入口 solve() 与操作说明测试（issue 19）
tests/test_solver_route.gd    Solver 配置缺口与方向 variant 测试（issue 20）
tests/test_solver_cycles.gd   Solver 循环证明与观测上限测试（issue 21）
tests/test_solver_spatial.gd  Solver 时序/空间证明分层测试（issue 22）
tests/test_replay_acceptance.gd  最终路线回放联合验收（issue 23：会话重现 + 训练场键盘对拍）
tests/diagnose_inputs.gd      搓招与空中运动诊断回路（逐帧诊断记录与症状判定）
```
