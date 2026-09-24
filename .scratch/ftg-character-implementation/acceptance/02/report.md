# 票据 02 验收记录：蹲姿普通技与低浮空扫倒

日期：2026-09-24。票据：`issues/02-crouch-low-float.md`（阶段 3 第 2 票）。
参数版本：frame-data.md v0.4（TUNING_INITIAL）。

## 交付内容

- **资源 schema**：MoveData 新增 `requires_crouch`（蹲姿限定：输入帧方向数字 ∈ {1,2,3} 才是单键候选，空中非法声明整表拒绝）；HitProfile.Reaction 新增 `LOW_FLOAT_SWEEP`（仅 grounded 键；air_untech_frames＝低浮空受击窗口、upward_speed_px_s＞0＝离地速度、knockdown_frames＝触地后倒地计时，foreign timer 校验沿用）；CombatEvent 新增 `LOW_FLOAT_LANDED`（触地转普通倒地边界）。
- **资源迁移**：新建 2A（5/4/10、伤 8、low、30×20 g1、grade A、链 5A/2A/5B/2B）、2B（7/5/12、伤 11、low、40×22 g2、grade B、链 5C/2C/6A）、2C（9/3/18、伤 14、low、52×18 g3、grade C、LOW_FLOAT 资料：窗口 20/counter 26、离地 120、倒地 30）；5A 链边加 2B、5B 链边加 2C；manifest 收录（顺序 5A,2A,5B,2B,5C,2C,…）。蹲姿招式 priority 2A=3、2B/2C=2，与 5X（1）、6A（2）分层不并列。
- **CombatSession**：蹲姿选招按当帧输入状态（不消费方向历史——持续按住下连续按键成立）；DummyState 新增 LOW_FLOAT_SWEEP（可追击域成员、受击摩擦同口径）；命中应用按 profile 进入低浮空（受击窗口入 hitstun 计数、倒地计时按当帧时间层预换算入 knockdown 计数、离地速度与浮空同口径施加）；运动阶段触地同帧转 GROUND_KNOCKDOWN、发 LOW_FLOAT_LANDED、以 KNOCKDOWN 原因结束连段（运动阶段先于取消窗口关闭结算）；窗口先于触地耗尽时按浮空受身结束；倒地后既有无 OTG 语义复用。reaction_timer_frames 覆盖 LOW_FLOAT（玩家侧反馈口径）。
- **训练场**：HUD 状态行新增「低浮空（N）」；事件行显示「低浮空触地 → 普通倒地」与连段结束原因（五种 ComboEndReason 全部可读）。
- **Solver**：`_dummy_pursuable` 覆盖 LOW_FLOAT_SWEEP（恢复观测至触地转倒地为止）；`_compile_chain` 为蹲姿招式的按下帧携带下方向（ ScheduledInput.down，回放与指南一致，指南按「F%d 按 ↓+键」标注）；首招候选/绑定 variant 行标注蹲姿；取消边理由注明「蹲姿按键」。

## 回放证据（acceptance/02/replay-routes.log，60 px 身体中心水平）

- `2A > 2B`：双面向各 2 hit、总伤 12.9（A 起手层 0.72/0.648），木桩自然受身结束（F39）。
- `5B > 2C`：双面向各 2 hit、总伤 20.7（B 起手层 0.84/0.756）；F28 命中进 LOW_FLOAT（窗口 15、滞空约 11 物理+8 停顿）、F45 触地转普通倒地（计时 23）并发 COMBO_ENDED/KNOCKDOWN、F68 自然恢复。
- `2C` 单招：双面向各 1 hit、伤 13.0（C 起手伤害层 0.93、时间层 0.90：窗口 18、倒地 27）；F30 取消窗口关闭结束连段、F31 触地转倒地、F58 恢复。
- 负例 `2C` 挥空（200 px）：无任何接触事件，木桩中立，无低浮空。
- 负例 `2C` 后 `5D` 追击：F30 LINK_FAILED/CONFIGURATION_GAP（2C 未声明 5D 边）；重按 5D 独立起手，判定全程落在普通倒地——1 hit 不变、倒地计时不受刷新（F58 恢复不变）。

## 自动化证据

- 全量：`acceptance/02/full/summary.json` —— 16 个作业全部退出 0、无脚本错误，共 **2531 PASS**（Windows PowerShell 5.1 仍会因测试预期的 stderr 中断官方脚本——与票据 01 同款现象，恰停在 test_move_table 的「资源无法加载」负例；后 9 个作业以相同引擎参数与判定口径补跑，test_smoke 首次补跑参数误用 main-smoke 的 `--quit-after`，已按正确 `-s` 参数重跑并采用该行）。
- 用时观察：solver 系列套件随表规模显著变长（combo_solver 349s、route 439s、spatial 582s、cycles 385s、entry 344s）——枚举完整性与诚实报告优先，本票不做性能优化。
- 正例断言：test_combat_session 票据 02 组（蹲姿选招/重按回归、2A>2B、5A>2B/5B>2C、2C 生命周期、修正跨浮空）；test_move_table（新 schema 校验、清单顺序、基线数值、链边）；test_combo_solver（蹲姿边、27 条边、路线与按下帧下方向、A 起手衰减截断如实上报）。
- 反例断言：挥空（`_test_2C_whiff_no_low_float`）、对空 MISS_NO_PROFILE（`_test_2C_airborne_target_miss_no_profile`，探针表放大 2C 判定框只为命中资料键的可观察性）、5D 配置缺口与无 OTG（`_test_2C_then_5D_fails_and_no_otg`）、倒地不刷新计时（同前，F58 精确断言）。
- 回归：HitProfile 精确匹配、Hitstop、自然恢复、资源整表拒绝、既有玩家防御/投/拆投全部保留（全量退出码见 summary.json）。

## 交付边界（如实声明）

- `2C > 214C~B` 出口未接通——214C 首段与派生属票据 04；2C 本票无任何取消出边（必杀取消目标将随 04 加入）。
- `2D` 高度不匹配负例未接通——2D 资源属票据 07（阶段 6）；当前表内无 2D，Solver 无从探测高度失败，该负例随 07 复验。
- 被防负例（2C 被防不进入低浮空）待票据 03 的木桩防御入口；本票以挥空负例覆盖「无接触不进状态」。
- A 起手下 `2A > 2B > 2C` 第三击不成立（2B 受击窗口 floor(14×0.658)=9 < 2C 前摇到达 10）——时间层衰减的诚实结果，是否放宽待试玩（frame-data v0.4 观察项）。
- 低浮空受击窗口先于触地耗尽时的兜底按浮空受身处理（AIR_RECOVERED + DUMMY_RECOVERED 结束连段，不产生倒地）——S-06 只定义了触地转换；当前调校初值下滞空（约 12 物理帧）远短于窗口（≥12），该分支不可达，票据 10 调校变慢触地时需复验此语义。
- 2A 命中框远缘 55 px 与 5A 的 56 px 同样在 80 px 空间档相邻不相交：Solver 空间层如实报 2A 起手路线 80 px 失败（与 5A 同一边界现象）。
- Solver 全量分析用时随表规模上升（新增 3 招与 9 条链边）：solve() 单次约 1 分钟量级，含空间复验的套件更久——枚举完整性与诚实报告优先，未做性能优化。

## Code review 记录（提交前，双轴）

- Standards 轴：无硬性违规；判断项采纳 1 项——`_direction_digit() in [1,2,3]` 的三处魔数字面量收敛为 `CombatSession._down_held()`（蹲姿姿态与蹲姿选招同一口径），复跑覆盖套件（combat_session 721 / crouch 45 / input_norm 22 / smoke 123）全绿；其余判断项（solver 与会话各自的 `_dummy_pursuable`、reaction 分派级联等）为既有结构，不在本票重构。
- Spec 轴：无缺失、无越界实质项；记录 2 项——HUD 连段结束原因全量映射属 AC6 范围内的自然完整；空间层 2A 起手 80px 边界行为变化已在本报告交付边界注明。
