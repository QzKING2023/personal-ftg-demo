# 票据 06 验收报告：蓄力 D、计划位移与真实换边

日期：2026-09-27。参数版本：frame-data.md **v0.8**（TUNING_INITIAL）。运行环境：Godot 4.5.1 headless。
证据：本目录 `replay-routes.log`（双面向真实位移回放 R1–R8）；单元测试 `tests/test_charge_motion_sideswap.gd`（55 断言含 Solver 蓄力边）；全量自动化见 `full/`（run_acceptance.ps1 输出，2026-09-27）。

全量自动化结果：16 个测试文件 + main-smoke。13 个一次全绿（charge_motion_sideswap 55、combat_session 853、combat_session_restore 98、crouch 45、hit_profiles 105、input_normalization 22、joint 28、move_table 284、replay_acceptance 123、smoke 123、solver_cycles 30、solver_entry 49、solver_spatial 6418）；combo_solver/solver_cache/solver_route 的 4 处断言在全量运行途中被修复（边计数 36→43、NaN 缓存键、route 边计数）——`full/` 中为旧断言失败记录，修复后逐文件复跑见 `full-rerun/`（combo_solver 582P、solver_cache 16P、solver_route 5390P，全部 exit 0、零脚本错误）。

## 资源与参数版本

- 新 schema：`MoveData.motion_x_px/motion_y_px`（计划位移，两轴成对）、`MoveData.charge_threshold_frames/charge_move_id/charge_only`（动作内蓄力）；MoveTable 整表校验（motion 成对/投不位移、蓄力对（入口唯一、目标 charge_only、同姿态同键、不链式）、charge_only 不入任何接续目标与并列键、孤儿蓄力版拒绝、阈值 ≥1）。
- `data/moves/5D.tres`：`motion=(72,0)`、`charge_threshold_frames=8 → "5[D]"`。
- `data/moves/5D_charge.tres`（新）：`move_id="5[D]"`、7/4/22、伤 20、命中框 70×28 gap 4、`motion=(120,0)`、`charge_only`、profile 镜像 5D 三组（grounded 14/320、airborne 32/80/170、slide 32/60/170）、`special_entry_link_targets=["5B"]`、被防 8/9/45。
- `data/move_manifest.tres` 追加 5D_charge.tres。
- 事件：`CHARGE_COMMITTED`（from/to/年龄/是否蓄力版）、`SWITCHED_SIDES`（新面向）。
- 训练场诊断行新增 蓄力（龄/蓄力版）与 位移（锁定方向·穿越·墙截）段；事件注记蓄力提交与换边。

## 行为锚点（单元与会话实测，全部真实位移）

| 项 | 结果 |
| --- | --- |
| 点按 D | 5D 正常时序（F1 按下 → F8 首判定、伤 18）；无蓄力版提交 |
| 按住 D ≥8f | F9 提交 5[D]（CHARGE_COMMITTED、年龄 8）、F10 首判定（伤 20）；有效前摇 = max(前摇−1, 阈值)+1 = 9 |
| 暂停中松开 | F9 提交普通版（延迟计入），F10 命中、伤 18 |
| 启动前按住 | 无新按下不构成请求；之后真按下自动作启动计龄（F21 按下 → F29 提交） |
| 挥空位移 | 5D/5[D] 全程 72/120px 照常走完；startup 0px；速度积分不受影响 |
| 中步扫掠 | 起点姿态与木桩不重叠、步长跨入时该帧命中（M-03，包络口径无采样误差） |
| 命中不足轨迹 | @70px 浮空捞起：终点重叠 → 截原侧身体边界（−48px），无换边 |
| 被防 | 截原侧 −48px，无 SWITCHED_SIDES |
| 版边 | 命中照常、墙截断标记可观察、不换边、不出界（双面向） |
| 中板穿越 | @50px `236C>5[D]`：F30 蓄力提交、F31 命中（锁定方向击退）、F42 真实越过 → SWITCHED_SIDES、下一帧面向翻转、当招 hitbox 仍朝锁定方向（双面向一致） |
| 方向候选 | 换边后新候选按新面向折算（236C 起手）；换边前已开始候选锁定原面向（新面向前向折为 4、234 断链） |
| 5B 目押 | 蓄力 5[D] 声明来源限定边：D 收招 F64 当帧消费 5B（合法接续）；默认表下木桩 F67 恢复早于 5B 判定（F70）——注入 untech 44 表三击成立（F70，第 3 击） |

## 回放输入（replay-routes.log，保留真实位移/击退，无钉位）

| 场景 | 起始间距 | 面向 | 输入要点 | 结果 |
| --- | --- | --- | --- | --- |
| R1 中板蓄力穿越（前置浮空时机） | 50px | ±1 | 236 搓招+C@F4；D@F16 按住至 F30 | 段1 F13（8.0）→ F30 蓄力提交 → F31 命中（18.0）→ F42 穿越换边（下一帧面向翻转）|
| R2a 换边后新候选 | 50px | ±1 | 换边后 2/(2+新前)/新前 + C（收招后） | 236C 按新面向起手 |
| R2b 提前搓招锁定 | 50px | ±1 | F17-18 录 2、3（换边前）；换边后新面向前向+C | 折为 4、234 断链，不起手 236C |
| R3 airborne 236C | 50px | ±1 | 236+C；段 2 命中空中目标（untech 30 延长）；D@F26 按住 | 段2 F26 airborne 资料 → F42 提交、F43 捞起（16.2）→ 穿越换边 |
| R4 slide 捞起（蓄力） | 93px | +1 | 236+C；D@F30 按住 | 段1 挥空 → 段2 F18 → 触地 F36 slide → 5[D] slide 资料捞起 |
| R5 版边普通 5D | 贴墙 60px | ±1 | D@F1 | 命中照常、墙截断、不换边、不越界 |
| R6 挥空轨迹继续 | 200px | +1 | D@F1（点按/按住） | 72/120px 全程走完 |
| R7 被防不穿越 | 70px | +1 | 木桩站防；D@F1 | BLOCKED、截原侧身体边界 |
| R8 手动 665B/665C | 90px | ±1 | F1/F3 前、F20 B/C | 66 前冲 F3 触发、冲刺结束 F21 起手、命中 |

## Solver

- 边/路线总量：43 条边（票据 05 基线 36 + 6 条蓄力变体 + 1 条 `5[D] → 5B` 来源限定出边）、203 条可读路线（含 5[D] 的时序路线，jD 空中路线 15 条保持）。
- 蓄力变体边：目标声明蓄力的每个接缝另验证蓄力提交（`236C → 5[D]（蓄力）` 特殊进入 valid；`5B/5C → 5[D]（蓄力）` 链式 valid；普通连接边如实报目押超时；`5[D] → 5B` 来源限定边在默认表下报目押超时——与会话实测一致）。
- `5[D]` 不作为单键路线起点（`_start_key_for` 排除、`_is_plain_start_id` 排除）；上下文经 `_context_via_charge` 由普通版入口链 + 蓄力链接构造；结果缓存请求键纳入 5 个新字段。
- 循环状态键自本票起包含双方横向位置、动作锁定方向、蓄力年龄/开闭与穿越许可（位移使横向几何成为真实结算量）；真实穿越/墙边/双面向换边维持 replay-required（SCOPE_TEXT 已扩展）。
- 已验证范围：钉位 timing/spatial 层；未支持：自由走位、身体推挤、屏幕边界搜索与真实换边证明（回放承担）。
- 缓存键：`_canonical_variant` 为 NaN 增加确定性编码 "Fnan;"（motion 字段的未声明哨兵不应使整键退化为不支持而绕过缓存）。

## 失败断点与修复记录

1. 初版参考面向锁定过宽（任何非空历史都锁）→ 破坏既有持键折转与镜像搓招测试 → 收窄为「已开始、未完成的指令候选」（方向段后缀 × 指令前缀的连续匹配，过滤中立段与识别器同口径）。
2. Solver `_fill_cancel_edge` 报告文案引用未声明变量（to_id）→ 改 edge.to_id。
3. `5[D]` 上下文不可达（`_special_entry_context_candidates` 按声明 id 查授予者，表内声明的是普通版）→ 蓄力目标按普通版翻译授予检查、尾链仍按蓄力编译。
4. 蓄力 5B 目押在默认表下三击不可达（组合等待 + 5B 前摇消耗剩余硬直）→ 单元测试以注入表验证完整正例，默认表现象记录为调校观察项（与票据 05 观察项同源）。
5. 蓄力变体插入时误把既有 edge_kinds 赋值缩进进新块内部——普通接缝类型全部丢失（空中路线整体消失、多数路线静默按取消接缝模拟）。逐层二分（面向门控 → 蓄力枚举开关 → 逐帧调试打印 → walk 现场 kinds=0）定位后恢复缩进；test_combo_solver 的 36 边计数同步更新为 43。

## Code-review 修复（两轴评审后、提交前）

Standards 轴：`_commit_charge` 注入表目标缺失时如实按普通版提交（charged=false，不谎报）；移除 `_links_for_edge` 死回退与 `_charge_base_of` 死子句；新状态字段三处重复初始化收敛为 `_reset_move_tracking()`（combat_session 853 断言复验）；蓄力链接克隆两处重复收敛为 `_clone_charged_link`；蓄力暂停分支去掉冗余相位赋值；测试文件续行符修正；move-data 招式计数 11→17。
Spec 轴：`_freeze_edge/_thaw_edge` 补 `charged` 字段（缓存命中不再丢失蓄力标注，test_solver_cache 16 断言复验）；Solver 有效前摇/延长边界统一按普通版 startup（运行时在普通版 active 边界仲裁，两者当前同值）；6D/jD 位移数据缺席记入 frame-data 观察项。
修复后复验：test_combat_session 853P、test_charge_motion_sideswap 55P、test_solver_cache 16P，全部 exit 0。

## 待真人（EXPERIMENT_REQUIRED）

- 蓄力阈值 8（有效延迟仅 +2 帧）的可操作性与 5[D] 收招 22 的节拍。
- 穿越后镜像指令手感、版边穿越手感、扫掠包络边界容差。
- `236C > 5[D]` 后 5B 目押的击退/位移联动调校（默认表下差 3 帧）。
- 236C/214C 自身计划位移（28/36、−24/−8/−4）仍未落表——影步距离属后续调校轮，motion 机制已就绪。
