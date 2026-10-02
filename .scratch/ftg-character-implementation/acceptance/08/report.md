# 票据 08 验收记录：空中 D 系与落地接续

日期：2026-09-29。范围：`.scratch/ftg-character-implementation/issues/08-air-d-landing.md`（阶段 7）。
资源版本：frame-data v0.10（票据 08 落表段）。引擎：Godot 4.5.1.stable.mono（headless）。

## 交付

- 资源：`j5D/j6D/j2D` 入 manifest（旧 `jD` 移除）；`jA/jB/jC` 取消边与 `6D/2D` 空中出口接至三新招（j214D 随票据 09）；`MoveData.hit_landing_cancel_targets/window` 新字段（MoveTable 成对/姿态/跨招式校验）。
- 运行时：落地统一结算（速度积分与计划位移两条入口共用首帧锁/落地恢复/接缝确认——j6D/j2D 的向下位移段不能绕过）；空技延迟普通连接（j6D）；j2D 命中落地取消例外（L-01：实际 HIT 授予、专用输入槽（Hitstop 可缓存、正常帧计龄、窗口 24）、落地首帧锁、落地后首个可行动帧一次性消费、连段/目标绑定、挥空/被防/缺失 profile/命中前预存/非法目标一律不适用）。
- Solver：`EdgeKind.HIT_LANDING_CANCEL` 独立边类型（与 NORMAL_LINK 分别报告）；空技 `link_targets` 的落地延迟普通连接按尾部发现运行验证（前缀严格复验 + 尾部放行预期外命中并要求连段延续）；空中方向记法（j6D/j2D）经 feed 喂入可表达；落地接缝按多上下文候选（规范/取消/空中出口进入）探测并注明入口。
- 训练场：诊断行新增「接缝」段（落地取消资格·输入年龄·已落地 / 待目押）。
- Solver 结构性修复（全量前置）：`_enumerate_gaps` 误置于 from 循环内（×N 全量重扫+缺口重复累计）提出单次枚举；空→空 NORMAL_LINK 缺口候选沉默（落地延迟连接锚定地面姿态，结构不可达）；`_delay_dfs` 的 64 延迟向量预算改为叶子计数+opts 回写共享（原局部副本从不生效，空中取消链失败路线枚举整棵延迟笛卡尔积致路线阶段失控）。修复后 solve() 1109s/双面向（71 边 54 有效、1753 路线、389 缺口、0 有效循环、mirror 一致）；循环证明模式不受预算限制。

## 实测锚点（@50px 双面向，回放见 replay-routes.log）

- R1 `2C>6D>j2D>214C` 四击 F13/31/48/65：j2D 首个 active 帧命中且同帧落地（最后空中帧先结算命中再落地）；停顿 F49–56 冻结；落地当帧 F48 锁定（无新招）；F57 例外消费 214C（当时落地恢复余 5——正常可行动要到 F62；「跳过其余空技恢复」可观察）；第 4 击同连段。
- R1b 独立跳 j2D 对地命中 F24、落地 F36：落地当帧按下的 214C 记录但不消费，F37 消费（「落地首帧记录但不消费」）。
- R2 `2C>6D>j6D>5B` 四击 F13/31/47/66：落地 F56，5B 于 F60（完整 3+1 恢复后首个合法帧）按延迟普通连接消费；j6D 命中时木桩为空中目标、命中后保持浮空；比 j2D 例外晚 3 帧，两机制可区分。
- R3 `2C>6D>j5D` 三击收束（取消窗关闭结束）；挥空落地恢复 3+1 全程承担。
- R4 反例组：挥空（落地帧断连、214C 至早正常恢复后独立起手）；命中前预存（不补发）；被防（无资格）；非法目标 236C（资格落地后失效断连）；j6D 同场景不借例外。
- R5 `5A>5B>5C>6A>jc.jB>j5D` 六击（jB 命中确认取消进空中 D 系）。
- R6 独立跳 j2D 对地目标（grounded 资料）> 214C——地空目标都取得一次性资格。
- Solver 边（钉位探针）：`jA/jB/jC → j5D/j6D/j2D` 取消边全部有效（hit_age 6/7/8，方向派生经 feed）；`6D → 三招` 空中出口有效（经 2C 链式进入上下文）；`2D → 三招` 出口在固定钉位不可达（命中依赖高浮空）——如实断链并标 replay-required（与票据 07 结论同源）；`j2D→214C` 命中落地取消有效（wait 1、hit_age 12）；`j6D→5B` 空技延迟普通连接有效（经 6D 空中出口进入，wait 2、hit_age 15）。
- 快照/恢复：test_combat_session_restore 随机拆分差分 3×12099 项通过（新状态完整入 clone/restore/settlement_state）。

## 自动化

- 单元：tests/test_air_d_landing.gd 全绿（例外正反例、最后空中帧、active 截断、出口接线、地空目标、资格绑定）。
- 回放：tests/acceptance_replay_08.gd 全绿（R1–R6，日志 replay-routes.log）。
- 全量：tools/run_acceptance.ps1 输出 `full/`（summary.json + runner.status.txt；逐 job exit/script_errors 判定）。结果（2026-10-02 回填，口径见下）：

- **当日子集（中断，未完成归档）**：`full/` 无 runner.status.txt；summary.json 仅落盘 2 job——import（exit 0，6.6s）与 test_air_d_landing（exit 0，96 断言）；`test_charge_motion_sideswap.log` 为中断前残留（无 summary 条目）。票据当日未重跑全量，成本问题（预计 10–15 小时，见观察项）随后由 acceptance-speedup 工程解决。
- **全量绿（后续补齐，含本票全部代码）**：期望同步 `bd7a0be`（test_combo_solver 71 边基线）与 `4b900d9`（entry/replay 空中起始与左向镜像）之后，`b71ed6c` 归档冷扫终证：冻结树 `2352684`、22/22 job exit=0/script_errors=0、19,342 断言、墙钟 53.28min（≤1h 目标）；Tier B 与 02 串行基线对拍全字段一致。证据：`.scratch/acceptance-speedup/final-07/EVIDENCE.md`。当日未完成的全量以该终证为准，不冒充票据当日实测。

## 观察项与限制（EXPERIMENT_REQUIRED / replay-required）

- j2D 落地例外节拍（停顿中按键 vs 落地帧按键 vs 恢复中补按）与 24 帧窗口富余度、j2D 挥空额外恢复 2 帧的手感——待真人试玩（阶段 9）。
- j6D 对空命中后木桩浮空保持（up 120）与 5B 目押窗口（约 6 帧缓存）的真实距离容差；中远距击退漂移下的可用性。
- j2D「带到地面」当前以 up 40 小上抛+重力回落表达（木桩与攻击者先后落地）；DOWNWARD_SLAM 触地即倒地会截断 214C 接续，未采用（设计裁量，见票据 Comments）。
- j6D 空间成立、j2D 落地节拍与地空目标差异、三招视觉/碰撞对齐：replay-required；固定钉位结论不冒充空间证明。
- Solver analyze 耗时随新边集增长（既有已知问题的延续，见 frame-data 票据 08 观察项）：结构性缺陷已修（见交付节），剩余为图规模增长的诚实成本（单次 analyze ≈ 562s vs 票据 07 ≈ 191s；路线枚举与循环证明为主要成本）；结论不受影响，时长如实记录于 summary.json。全量预计 10–15 小时（票据 07 为 5.6 小时）。

## 待真人（阶段 9）

j2D 落地首帧与首个可行动帧的输入节拍、j6D 普通连接距离、三招视觉／碰撞对齐。
