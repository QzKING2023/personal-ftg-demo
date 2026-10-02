# 08: 空中 D 系与落地接续

Status: implemented
Type: HITL
Stage: 7
Blocked by: 04, 07
验收：2026-09-29 完成，证据见 [acceptance/08/report.md](../acceptance/08/report.md)（单元/回放/全量自动化）。待真人：j2D 落地例外节拍（停顿中按键 vs 落地帧按键 vs 恢复中补按）与 24 帧缓存窗口富余度、j6D 目押窗口的距离容差、j5D 收束手感、三招视觉/碰撞对齐（阶段 9）。

## What to build

交付 j5D 收束、j6D 普通落地连接和 j2D 实际命中后的专用 214C 落地取消。三招各自保留真实运动、地空命中资料和空技落地恢复；j2D 例外不扩大到 j6D 或其他空技。

## User stories covered

15, 16, 21, 22, 23。

## Acceptance criteria

- [x] j5D 可命中地面或空中目标并按资源收束，不产生 bounce 或落地特权。（grounded 14/18·h200、airborne untech 22/28·up60·h200，motion 74/0 水平扫掠；无取消/连接/落地资格，路线经取消窗关闭或落地截断自然结束——`_test_j5d_closer_ends_route`、`_test_j5d_whiff_bears_landing_recovery`、回放 R3。）
- [x] j6D 命中空中目标后攻击者完成普通落地恢复；恢复后普通地面连接必须重新检查目标硬直、距离和姿态，不能共享 j2D 例外。（`link_targets=["5B"]` 空技延迟普通连接：落地恢复 3+1 完成后的首个合法帧按缓存消费、按目标剩余硬直/姿态/active 重叠重判；实测 5B 于落地 F56 后 F60 消费（`_test_j6d_hit_normal_recovery_then_link` 双面向、回放 R2）——比 j2D 例外（F+1）晚 3 帧，两机制可区分。）
- [x] j2D 实际 HIT 才取得一次性 J2D_LANDING_214C 资格；Hitstop 中输入可缓存，落地首帧记录但不消费，首个可行动帧启动 214C 并清除资格。（专用槽 `_hit_landing_input_*` 正常帧计龄、窗口 24；实测 2C>6D>j2D 命中 F48=落地帧（最后空中帧先结算命中再落地），停顿 F49–56 冻结，落地当帧锁定（无新招），F57 消费 214C（落地恢复余 5——正常要到 F62），F65 第 4 击；R1b 落地当帧按下（F36）记录不消费、F37 消费。）
- [x] j2D MISS、BLOCKED、缺失 profile 和其他空技命中不能取得该资格；非法目标只能按普通落地恢复处理。（`_test_j2d_whiff_no_landing_cancel`（挥空落地帧断连、214C 至早正常恢复后独立起手）、`_test_j2d_blocked_no_qualification`、`_test_j2d_prehit_input_no_autofire`（命中前预存不补发）、`_test_j6d_no_j2d_exception`、回放 R4a–e（含 236C 非法目标：资格落地后失效断连）。）
- [x] 最后一个空中物理帧先结算 active 命中，再进入落地恢复；落地后不延续剩余 active。（`_test_j2d_last_air_frame_hit_settles_before_landing`：命中帧=落地帧；截断后 player_move_id 清空、单次接触；速度积分与计划位移两条落地路径统一走 `_handle_landing`（首帧锁/落地恢复/接缝确认），j6D/j2D 的向下位移段不能绕过。）
- [x] 正例：j2D 命中 > Hitstop 输入 214C > 落地首帧锁定 > 首个可行动帧 214C；j6D 命中 > 恢复 > 普通 5B。（回放 R1/R1b/R2 双面向；214C 第 4 击与 5B 第 4 击均入同一连段。）
- [x] 反例：j2D 挥空仍落地取消、命中前预存 214C 自动补发、j6D 共享专用例外、落地首帧攻击或防御、active 延续到落地恢复。（单元四反例 + 回放 R4；落地首帧攻击/防御由既有首帧锁断言（R1 落地当帧无新招）与 `_independent_start_allowed` 门承载。）
- [x] 修正跨空中 D 和落地继续段保留；专用资格只绑定当前目标和连段。（三层修正跨 j2D>214C/j6D>5B 连续累计（回放伤害序列）；`_test_j2d_qualification_bound_to_combo`：木桩受身→连段结束→资格清除，214C 不经例外补发；`_end_combo` 统一清除资格与延迟连接挂起。）

## Solver and replay scope

- 新增 `EdgeKind.HIT_LANDING_CANCEL`（j2D→214C，区别于 NORMAL_LINK 的独立边类型）；空技 `link_targets` 的 NORMAL_LINK 按「落地恢复完成后首个合法帧消费」的延迟模型验证——两者起手帧都由真实落地结算锚定，探针以「尾部发现」运行（`_run_tail_discovery`：前缀按预测帧严格复验、尾部放行预期外命中并记录帧号），落地首帧锁与消费帧在边报告可读。
- 空中方向记法（j6D 的 6D/j2D 的 2D）由 feed 机制喂入——取消/出口/起手链接统一可表达（此前空中带记法招式不可表达）。
- 回放证据：acceptance/08/replay-routes.log（R1–R6 双面向）；j6D 空间成立、j2D 落地节拍与地空目标差异、三招视觉/碰撞对齐标记 replay-required（SCOPE_TEXT 票据 08 段），固定钉位结论不冒充空间证明。

## Human judgment

必须确认 j2D 落地首帧与首个可行动帧的输入节拍、j6D 普通连接距离和三招视觉／碰撞对齐；规则自动化通过仍需真人试玩。

## Blocked by

- 04
- 07

## Comments

- 2026-09-29 实施：jD 移除（manifest/资源），jA/jB/jC 取消边与 6D/2D 空中出口接至三新招（j214D 随票据 09）；`MoveData.hit_landing_cancel_targets/window` 新字段 + MoveTable 成对/姿态校验；CombatSession 落地统一结算（计划位移落地不再绕过恢复）、空技延迟普通连接、j2D 例外（授予/专用输入槽/一次性消费/连段绑定）；旧票据 jD 断言迁移（test_move_table/test_combat_session/test_combo_solver/test_hit_profiles/diagnose_inputs）。
- 2026-09-29 Solver 结构性修复（全量前置，非行为语义变更）：(1) `_enumerate_gaps` 自 HEAD 起误置于 from 循环内——每次全量重扫 ×N 且缺口条目重复累计，提出循环外单次枚举（389 缺口去重，缺口阶段 2.7s）；(2) 空→空 NORMAL_LINK 缺口候选沉默——落地延迟连接锚定地面姿态、空目标结构不可达，不再为不可达接缝跑多上下文×45 等待的落地接缝扫描；(3) `_delay_dfs` 路线模式的「至多 64 个延迟向量」预算原为局部副本、从不回写——从未生效，空中取消链上的失败路线枚举整棵延迟笛卡尔积（单路线数万次全量回放，路线阶段 >10 分钟不归）；改为叶子回放计数并经 opts 回写共享，循环证明模式不受预算限制（语义不变）。修复后实测：solve() 1109s 双面向、71 边（j2D→214C w1/h12、j6D→5B w2/h15、jA/jB/jC→三空 D 全 valid）、mirror 一致；票据 08 新边结论不受影响。
- 设计裁量记录（TUNING_INITIAL，见 frame-data v0.10 票据 08 段）：j2D「带到地面」以小上抛（up 40）+重力回落表达——DOWNWARD_SLAM 触地即倒地会截断 214C 接续，未采用；j2D 额外落地恢复 2 帧仅作用于挥空/被防路径；收束不设 is_finisher（路线经取消窗关闭自然结束，与旧 jD 的 FINISHER 语义区分已在旧测试迁移中体现）。
- 2026-10-02 档案归位：acceptance/08/report.md 全量占位符回填（当日子集中断——summary 仅 2 job、无 runner.status；全量绿以 acceptance-speedup 07 终证 `b71ed6c`@冻结树 `2352684` 为准，含期望同步 `bd7a0be`/`4b900d9`）；票据文件与验收证据按 01–07 约定入 git（runtime*/appdata 目录不入库）。
