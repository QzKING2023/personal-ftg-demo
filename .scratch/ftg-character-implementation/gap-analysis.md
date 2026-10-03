# 角色招式实施差异核对（阶段 0）

日期：2026-09-23  
目标行为：`docs/player-character-move-design.md` 的 2026-09-23「角色招式完整设计基线」。  
范围：只调查设计、领域文档、ADR、历史规格/票据、当前代码、资源和测试；本阶段没有修改战斗代码或招式参数。

## 口径与证据

资料优先级按路线图执行：完整招式设计基线 → 角色设计与 2026-09-23 覆盖记录 → CONTEXT/ADR → 当前招式说明 → 旧规格、票据和验收 → 当前代码、资源与测试事实。设计文档明确声明“设计不代表代码已经实现”，因此资源和旧测试不能反向覆盖新基线。

证据标签如下：

- **当前检查**：本次读取代码/资源/测试，或本次独立运行的结果。
- **历史证据**：旧票据、旧规格或旧验收记录中的实现/测试结果；没有在本轮复写成当前实测。
- **设计**：目标规则或约束，不是实现证明。

本次独立检查命令为 `tools/run_acceptance.ps1 -Output '.scratch/ftg-character-implementation/acceptance-phase0-check'`。导入、12 个 `test_*.gd`、`diagnose_inputs.gd` 和主场景冒烟均退出 0，脚本错误为 0，共 **1599 条 PASS**；明细在 [`summary.json`](acceptance-phase0-check/summary.json)。这只证明当前实现仍通过现有回归集合，不证明新基线的未覆盖能力。

## 已读资料与历史票据去重

| 资料 | 本轮用途 | 结论口径 |
| --- | --- | --- |
| [`player-character-move-design.md`](../../docs/player-character-move-design.md) | 逐招职责、取消、状态、位移、修正和路线目标 | 2026-09-23 当前行为目标；帧数、伤害、判定框和最终空间连接仍待验证 |
| [`player-character-design.md`](../../docs/player-character-design.md) | 角色体验背景及旧提案边界 | 逐招规则以完整设计基线为准；旧 `214D`、旧 `jD` 不能覆盖新设计 |
| [`CONTEXT.md`](../../CONTEXT.md) | 领域语言、帧序、面向、防御、受击、Solver 范围 | 当前共享术语和架构约束 |
| [`docs/adr/0001-lightweight-combat-resolution.md`](../../docs/adr/0001-lightweight-combat-resolution.md) | 确定性会话和训练场边界 | 运行时由 CombatSession 统一结算 |
| [`docs/adr/0002-natural-recovery-combo-rules.md`](../../docs/adr/0002-natural-recovery-combo-rules.md) | 自然恢复、连段结束、无全局上限 | 新的 slide/弹地/修正语义需要后继决策核对 |
| [`docs/adr/0003-contextual-hit-profiles.md`](../../docs/adr/0003-contextual-hit-profiles.md) | HitProfile 的字段与精确匹配 | 当前已实现的首版状态边界 |
| [`ftg-move-design/spec.md`](../ftg-move-design/spec.md)、`design-decisions.md` | C0–C9 已接受规则和 2026-09-23 覆盖记录 | 旧 C0–C9 保留；后续基线覆盖旧招式职责 |
| `ftg-move-design/issues/01-contextual-hit-profiles.md` | HitProfile 垂直切片 | 已有实现证据，不能重开同一票 |
| `ftg-combat-foundation/issues/11–23` | 资源、输入、Hitstop、跳跃、防御、投、冲刺、Solver、联合回放 | 已实现票据保留为历史依据；未完成项只在缺口表引用，不重复建票 |
| [`ftg-combat-foundation/acceptance-2026-09-17/report.md`](../ftg-combat-foundation/acceptance-2026-09-17/report.md)、`crouch-2026-09-18/diagnosis.md` | 历史自动化、蹲姿修复、人工验收边界 | 历史结果；修复后蹲姿真人复玩仍未有新记录 |

旧票据中已有的共享资源、HitProfile、输入指令、Hitstop/缓存、跳跃锁、基础防御姿态、普通投、冲刺、Solver 循环/静态空间和回放能力，本轮不创建重复票据。它们只有在新基线要求扩展语义时才作为复用点或依赖出现。

## 当前资源和代码基线

当前 `data/move_manifest.tres` 引用 11 个资源：10 个打击招式 `5A/5B/5C/6A/236C/jA/jB/jD/5D/214D`，以及普通投 `BC`。缺少新基线要求的 `2A/2B/2C/2D/6D/jC/j5D/j6D/j2D/214C/j214D/5[D]` 等稳定资源。当前资源的主要职责仍是旧切片：`5C` 和 `236C` 为浮空，`5D` 为收尾，`214D` 为地面倒地，`jD` 为唯一空中 D 收尾。

HitProfile schema 位于 [`hit_profile.gd`](../../scripts/combat/hit_profile.gd:1)，`MoveData.profile_for` 在 [`move_data.gd`](../../scripts/combat/move_data.gd:124) 做 `(target_state, hit_context)` 精确查找；MoveTable 在 [`move_table.gd`](../../scripts/combat/move_table.gd:243) 校验枚举、计时、速度、重复键和 Counter 同状态 normal 依赖。CombatSession 在 [`combat_session.gd`](../../scripts/combat/combat_session.gd:776) 和 [`combat_session.gd`](../../scripts/combat/combat_session.gd:875) 复用同一查找口径。

当前默认 profile 覆盖如下：

| 资源 | 当前 profile 事实 | 与 2026-09-23 基线的关系 |
| --- | --- | --- |
| `5A` | grounded normal/counter，地面硬直 | HitProfile 样例已实现；逐招职责仍需重画普通链 |
| `5B` | grounded normal，地面硬直 | 普通连接基础可复用；无 counter/air profile |
| `5C` | grounded normal，`LAUNCH` | 与新基线“普通地面重攻击”冲突，不能把旧浮空职责当目标 |
| `6A` | grounded normal/counter，`LAUNCH` | 专用 launcher/jump cancel 原语已存在；airborne profile 尚无 |
| `236C` | grounded normal，`LAUNCH` | 新基线需要 ground slide，而不是旧的单一浮空职责 |
| `5D` | grounded normal，地面硬直，`is_finisher=true` | 与普通 D 系位移、捞起、换边冲突 |
| `214D` | grounded normal/counter，普通倒地 | 新基线移除地面 `214D`，改为空中 `j214D` 弹地和地面 `214C` Rekka |
| `jA` | grounded normal 地面硬直；airborne normal 浮空 | 空中普通连接原语可复用；无新修正/位移字段 |
| `jB` | grounded normal 地面硬直；airborne normal 浮空；旧 `landing_cancel_targets=["5D"]` | 新基线要求恢复后普通连接，不能由旧字段绕过落地恢复 |
| `jD` | grounded/airborne normal，空中 D 收尾 | 新基线拆成 `j5D/j6D/j2D`，旧 `jD` 不能代表三招 |
| `BC` | 普通投 schema 和确定性拆投 | 与本轮招式连段差异无关，保留现有能力 |

默认表所有攻击属性目前为 high；只有空中资源声明 `air_attack=true`。low、overhead、ground slide、bounce 和独立伤害/时间/轨迹修正均未由默认资源表达。

## 逐项追踪表

状态：**已实现** = 当前代码有目标语义且本次检查/历史回归有直接证据；**部分实现** = 共享原语存在，但新基线的条件、资源或观察入口不完整；**待实现** = 代码/资源没有该能力；**待决策** = 阻塞实现的规则尚未在阶段 0 之外落定。

| # | 设计要求 | 当前代码/资源事实 | 已有证据（分历史/本次） | 缺口 | 待决策项 | 建议阶段 |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | HitProfile 按 grounded/airborne × normal/counter 精确匹配，缺失不得回退；反应为地面硬直、浮空、普通倒地 | `HitProfile` 枚举和 `MoveData.profile_for` 已实现；MoveTable 整表校验反应与字段组合；运行时命中和木桩攻击两侧复用 | 历史：C0–C9、ADR-0003、issue 01；当前：`test_hit_profiles` 105 PASS，`test_move_table` 131 PASS | 新基线新增 slide、bounce、low-float、landing/bounce 等状态无法由现有 Reaction 表达 | 新状态是否新增 TargetState/Reaction，及状态转换的同帧顺序 | 1（语义）→ 2（schema/票据） |
| 2 | 普通地面命中保持接地，浮空和普通倒地独立计时；Counter 只作用于当前命中 | `_apply_player_hit` 根据 profile 设置 `DummyState`、计时、水平/垂直速度；Counter 只在木桩 startup/recovery | 历史：issue 01、`test_hit_profiles` 验收；当前：完整检查通过 | 新的 slide、弹地、低浮空和落地接续没有状态/计时/恢复事件 | 新状态的自然恢复、可追击资格和是否结束 combo | 1 |
| 3 | `5A > 5B > 5C > 5D`、`5B > 5D`；`5C` 不再是专用 launcher；蹲姿普通技绑定明确 | 当前只有 `5A`→`5B/236C/6A`、`5B`→`5D/214D`；`5C` 无普通取消且仍 LAUNCH；无 `2A/2B/2C` | 历史：旧回放的 `5A→5B→5D` 通过；当前：回归仍通过该旧路线 | 新链边表、链式取消层、2 系资源和 5C 新职责未实现；旧 `5B→214D` 不应迁移为新基线规则 | 普通链资格在命中/被防时的独立窗口、5C/5D 的首轮帧数和空间可接性 | 1（取消语义）→ 2 → 3 |
| 4 | `6A` 是唯一专用击飞入口；命中后 jump cancel；5A/5B/5C 可进入 | `6A` 已有 grounded LAUNCH、`jump_cancel_targets=["jA"]`；取消实现要求命中确认、可追击和窗口 | 历史：issue 15、HitProfile 样例；当前：`test_hit_profiles` 与联合回放通过旧 6A 路径 | `6A` 无 airborne profile；5C/236C 资源职责未迁移；新普通链未接入 | 6A 对空是否需要独立 profile、jump cancel 的完整入口与实际距离 | 2 → 3/6 |
| 5 | 木桩被防路径必须能确定性验证“玩家攻击被木桩防住” | 当前 `dummy_move_request` 只让木桩发起打击；`_blocks_attack` 只判断玩家防御木桩攻击；没有 dummy guard posture/request 或 `PLAYER_ATTACK_BLOCKED` 事件。已有的玩家侧 BLOCKED 会把 `player_guard_stun_left` 设为所选 profile 的反应计时 | 历史：issue 16/23 只验证玩家站防、蹲防、空防挡木桩；当前：防御矩阵测试通过，但方向相反 | 无法测试玩家攻击的 blocked 资格、被防硬直、推退和取消 | 木桩防御如何请求/持续、被防事件字段、被防硬直/推退是否独立于受击硬直 | 1（防御规则）→ 2/4 |
| 6 | 链式/必杀取消：命中或被防成立，挥空不成立；与命中确认取消、jump cancel 分离 | `MoveData` 只有 `cancel_targets`、`jump_cancel_targets`、`landing_cancel_targets` 和一个 `cancel_window_frames`；`_phase_cancel` 只在 `_move_hit_confirmed` 时开放 | 历史：C0–C9 已接受分层，但旧实现仍单一路径；当前：回归覆盖命中/挥空和 jump cancel | 没有 blocked 接触标记、三类独立窗口/资格和普通恢复连接；被防不能进入新链 | 三类窗口起点、端点、优先级、被防硬直关系、B+C 仲裁与命中/被防同帧顺序 | 1 |
| 7 | 蓄力 `5[D]`：开始、阈值、松键、Hitstop 计时；普通 `5D` 与蓄力版有不同位移/修正 | 没有 charge 字段、按住/松开事件契约或蓄力计时；`input_alternatives` 只表示方向替代串 | 当前检查只验证普通动作键缓存和方向历史 | `5[D]` 无法声明、识别或在 Solver 中搜索；不能证明中板蓄力捞起 | 蓄力起点、最小阈值、松键消费帧、Hitstop 是否冻结蓄力年龄 | 1 → 2/5 |
| 8 | Rekka `214C` 首段命中/被防后派生 `~B/~C`，首次派生锁定，B+C 组合等待不改分支 | `214C` 不在 manifest；无派生状态、首段来源、延迟窗口或分支锁；现有 B+C 只服务普通投 | 历史：设计决策 B10/B11 只覆盖旧 `214D` 倒地；当前：无资源事实 | 首段/派生/地空 profile、分支锁和 Solver 输入均缺失 | 首次派生请求何时锁定、B+C 与 Rekka 派生如何仲裁、被防安全性如何观察 | 1 → 2/4 |
| 9 | `236C` 地面命中为浮空→ground slide；空中命中用普通空中资料；命中当下可特殊取消至 `5D/5[D]` | 当前 `236C` 只有 grounded normal LAUNCH、jump cancel→jA；无 slide 状态、专用 profile 或特殊来源资格 | 历史：旧回放验证 236C 浮空/jump cancel；当前：旧测试仍通过 | 新状态、有限持续、`5D/5[D]` 覆盖/挥空轨迹和特殊取消来源全缺 | slide 进入/结束帧、命中覆盖规则、空中 profile、取消资格消费与清除 | 1 → 2 → 4/5 |
| 10 | 特殊 `5D/5[D]` 在前置浮空或 slide 中命中后可接 `5B`；普通 `5D` 不可反向接 `5B` | 当前 `5D` 是 finisher，`cancel_targets=[]`；没有来源标签/一次性资格或 `5B` 出口 | 当前：无任何新基线资源/测试；历史旧 `5A→5B→5D` 仅是普通收尾 | 不能区分普通 5D 与 236C 来源 5D，也不能消费/清除特殊 5B 出口 | 来源资格是否绑定命中事件、跨 Hitstop/状态转换存多久、被防/挥空清除规则 | 1 → 2/5 |
| 11 | D 系真实位移、垂直判定偏移、命中穿越与换边：仅实际命中且穿过才换边 | `MoveData` 没有位移曲线/命中帧位移/身体碰撞例外；`_motion_player` 只处理普通移动、跳跃、冲刺；`_resolve_body_overlap` 只防身体重叠 | 历史：issue 12 只验证既有面向、跳跃动量和方向派生；当前：回放验证的是钉位/旧动作 | `5D/6D/j5D/j6D/j2D` 的真实轨迹、穿越判定、墙截断和姿态偏移全缺 | 位移在哪些帧结算、身体穿越/墙截断顺序、命中当帧与下一帧面向顺序 | 1 → 2 → 5–7 |
| 12 | 面向每帧朝向目标；已开始方向候选锁定首次相对面向，换边不重解释 | `_update_free_action_facing` 仅地面自由行动；方向段按帧首 `player_facing` 记录；招式期间面向保持 | 历史：issue 12、当前输入/回放检查通过 | 缺少 D 系实际穿越后的换边触发；候选锁与移动命中同帧顺序尚未在新路线验证 | 换边判定采用身体中心还是攻击轨迹，跨身/横向重合的优先级 | 1 → 5 |
| 13 | `2C` 低浮空/扫倒：5D 因慢失败，2D 因高度失败，`214C~B` 路线成立 | `2C/2D` 不存在；现有 LAUNCH 只有持续空中受击，没有低浮空或扫倒 | 当前：无新基线证据；旧 6A/5C 浮空测试不等价 | 低浮空持续、落地/普通倒地转换和失败原因均缺失 | 低浮空最短窗口、命中/取消同帧顺序、落地是否结束 combo | 1 → 2 → 3/4/6 |
| 14 | `j2D` 命中空中目标带到地面，仅可命中后落地取消 `214C`；`j6D` 无此特权，普通连接等恢复 | 只有 `jD`；`landing_cancel_targets` 旧字段在运行时被恢复锁阻断，Solver 将恢复后普通连接排除 | 历史：issue 15/23 已证明旧 jB→5D 落地首帧负例；当前：联合回放仍验证该负例 | 新空中 D 三招、`j2D` 专用落地例外、`j6D` 普通恢复后连接均缺 | `j2D→214C` 输入缓存消费帧、落地首帧锁与专用例外关系；`j6D` 目标硬直/距离门 | 1 → 2 → 7 |
| 15 | `j214D` 空中命中弹地；地面命中不弹；可由空中出口进入，A 起手不能继续，B 级以上条件性继续 | `j214D` 不在 manifest；没有 bounce reaction、地面/空中差异或起手等级 | 历史：ADR-0003 明确地弹只预留；当前：Solver SCOPE_TEXT 仍将 bounce 排除 | 弹地速度、触地/反弹事件、追击窗口、地面命中普通资料全缺 | 是否新建 BOUNCE/ground-contact 状态，弹地是否结束/继续 combo，触地同帧顺序 | 1 → 2 → 8 |
| 16 | `214C~B` 地面倒地、空中延长；`~C` overhead 直接倒地；地面 `214D` 移除 | `214C` 不存在；只有 `214D` GROUND_KNOCKDOWN；所有默认攻击属性 high | 当前：HitProfile 的普通倒地机制已测；不能视为 Rekka 已实现 | low/overhead 属性、派生结果、地空分支和恢复后的普通连接缺失 | `~B` 空中延长的剩余硬直、`~C` 是否 finisher、被防风险与反击观察 | 1 → 2 → 4/7 |
| 17 | 特殊受击状态：slide、低浮空、普通倒地、弹地、落地连接各自独立，状态转换不混用 | `DummyState` 仅 NEUTRAL/GROUND_HITSTUN/AIR_HITSTUN/AIR_RECOVERED/KNOCKED_DOWN；`HitProfile.Reaction` 仅三种 | 当前：`test_hit_profiles` 覆盖三种旧 reaction；历史 ADR 明确 OTG/地弹/墙反弹只预留 | 新状态没有可观察 enum、timer、event 或追击门；不能把新行为塞入旧 LAUNCH | 状态命名、合法来源、恢复事件、可追击域和状态键字段 | 1 |
| 18 | 修正：首击锁定 A/B/C/D；伤害与时间/轨迹分开累计，跨 slide/弹地/落地不重置；A 禁止 loop，B+ 有限延长 | 当前只按 `combo_hits` 做全局伤害衰减 `max(0.1,1-(n-1)*0.1)`；combo 开始/结束由状态和自然恢复决定；无 starter 等级或分层倍率 | 历史：ADR-0002/旧回放验证自然衰减和无全局上限；当前：回归验证旧衰减 | 无 starter grade、damage/time/trajectory 独立修正、跨新状态延续或 A/B loop 负例 | 起手等级锁定时点、每层累计/舍入、修正是否影响恢复/轨迹以及 loop 断开条件 | 1 → 2 → 8 |
| 19 | 木桩防御和取消要能验证命中/被防/挥空三分支 | 当前木桩无 AI；只有 `dummy_move_request` 自攻请求，玩家 guard posture 对称防御；`CombatEvent` 无玩家攻击被防事件 | 历史：issue 16/23 仅证明玩家挡木桩；当前防御专项全绿 | 无法确认被防普通链、被防 Rekka、被防 236C 不取得命中专用出口 | 训练设置/请求 API、木桩防御持续帧、被防推退和反击招式/距离 | 1 → 4 |
| 20 | 普通连接与取消分离；恢复后的普通连接须以真实硬直、距离和状态成立 | Solver 只枚举 `cancel_targets`、`jump_cancel_targets`、`landing_cancel_targets`；`_phase_cancel` 只在命中确认取消窗口开放；缺配置候选写入 gaps | 历史：issue 20/23 的 timing 回放和 gaps 通过；当前：`test_combo_solver`/route 通过 | 无独立普通连接图、被防边、恢复后空间搜索或新状态候选；不能把 gaps 当合法边 | 普通连接搜索的起点（恢复/取消）、目标硬直/距离条件、与取消边的报告分类 | 1 → 2 → 3/4/7 |
| 21 | Solver 必须携带真实空间状态、起手等级、累计修正、运动、位置关系和有限资源来判重 | `settlement_state` 已包含姿态、招式帧、面向、速度、垂直位置、受击/防御硬直、缓存、方向历史、落地和 jump 标记；明确不包含横向位置及纯报告计数 | 历史：issue 21 循环快照、issue 22 空间分层、当前循环/空间测试通过 | 横向位置仍是钉位假设；新修正、slide/bounce/来源资格字段不存在；不能证明真实换边/墙角/推挤 | 状态键是否加入横向相对位置、修正层、特殊来源 token、碰撞/墙状态 | 1 → 2 → 5/8 |
| 22 | Solver 普通连接、蓄力输入、特殊状态和真实空间范围不能伪装成已验证 | 当前 Solver 支持共享表、地面/显式空中起点、方向 variant、取消/jump/landing edges；无 charge、Rekka branch、slide/bounce、完整会话快照导入 | 当前：Solver 全套通过；`SCOPE_TEXT` 明确 OTG/地弹/墙反弹/无敌不支持 | 新基线路线只能显示旧能力或配置缺口；`to_lines` 是文本，稳定 version=1 JSON 仍缺失 | 新输入与状态如何进入 Solver，JSON schema/version 是否仍为阶段 9 依赖 | 1 → 2 → 各实施阶段同步 |
| 23 | 真实空间范围：中板/版边、左右面向、击退漂移、穿越和墙截断分别验收 | 空间 Solver 只钉回 48/64/80 px；`PIN_DX=70`，`settlement_state` 不存横向位置；真实键盘回放另测固定站位和击退漂移 | 历史：issue 22/23 明确 static pinned ≠ real knockback；当前：回放套件通过旧路线 | 未搜索走位、中立、墙角、推挤、跨身、屏幕边界；无法验收新 D 系穿越和换边 | 阶段 5 起需要的站位矩阵、墙边截断、真实击退回放和镜像判据 | 1 → 2 → 5/9 |
| 24 | 训练场反馈应显示当前招式、命中/被防、修正和失败原因 | 当前 HUD/诊断显示招式、属性、姿态、Hitstop、缓存/取消等；没有 slide/bounce/source token/修正层/被防玩家攻击事件 | 历史：issue 23/训练指南覆盖旧路线；当前主场景冒烟通过 | 新状态和失败原因没有可读字段；木桩防御入口也不可操作 | 反馈字段与测试请求如何暴露给训练场，是否保持单场景范围 | 2 → 4/5/8 → 9 |
| 25 | 旧 `214D`、`jD` 路线迁移；保留历史测试意义并把废弃路线变成负例 | 旧资源仍在 manifest，旧测试/文档仍能回放 214D、jD；新 CONTEXT 已写地面 214D 移除、D 系拆分 | 历史：联合验收把旧落地 `jB→5D` 改为负例；当前：旧资源和旧测试仍通过 | 尚未有迁移方案、旧 id 的兼容/删除策略、完整新资源 manifest | 是删除旧 id、保留 alias 还是分版本 manifest；旧回放作为负例的范围 | 1 → 2；资源迁移随 3–8 |
| 26 | 数值初表：帧数、伤害、hitbox、位移、受击计时和窗口可调整且有版本 | 现有 `.tres` 有旧样例数值；`GameParams` 仍有历史常量，运行时主要读取资源；无数值版本、位移/修正字段 | 历史：move-data 文件级同步改写 5A 证明资源驱动；当前：资源/表校验通过 | 新招及新字段没有首轮可调初值，不能从旧 5C/236C/214D 数值直接推导 | 阶段 1 需确定单位、时间基准、默认/必填、舍入和实验观察标准 | 1 → 2 |

## 已有能力与本阶段真正不应重复解决的事项

下列是当前可复用的基础能力，不列为阶段 1 阻塞决策：

- 共享 `MoveManifest`/`MoveTable`、稳定 id、整表拒绝和运行时/Solver 同源（历史 issue 11；当前 `test_move_table` 通过）。
- HitProfile 精确匹配、grounded normal/counter、LAUNCH、GROUND_KNOCKDOWN、Counter 生命周期和缺失 profile 的无副作用 MISS（历史 issue 01/C0–C9；当前 `test_hit_profiles` 通过）。
- 确定性帧序、8f Hitstop、动作/方向缓存、取消年龄 0–8 和挥空不获命中确认（历史 issue 14；当前 CombatSession/回放测试通过）。
- 面向、方向历史、严格/宽松指令、镜像输入、pre-jump/跳跃槽、空技落地锁、蹲下原地停住、玩家防御姿态、普通投/拆投和冲刺（历史 issue 12–18、蹲姿诊断；本次套件通过）。
- Solver 的 timing/spatial 标签、48/64/80 静态钉位、状态快照循环检查和旧路线回放（历史 issue 19–23；本次套件通过）。

这些能力的“通过”不能扩大为新基线行为已经成立。例如已有 5A→5B→5D 只能证明旧资源的命中确认链；已有玩家防御矩阵不能证明木桩防住玩家攻击；已有 236C 浮空不能证明 ground slide。

## 阶段 1 真正需要解决的问题

按依赖排序，阶段 1 只需要落定下列会阻塞规格和拆票的规则；实现本身留到阶段 3–9：

1. **取消和输入语义**：分别定义普通链、必杀取消、命中确认取消的资格、窗口起点/端点、命中/被防/挥空结果；定义蓄力 `5[D]` 的开始、阈值、松键和 Hitstop 计时；定义 Rekka 首个派生请求锁定及 B+C 仲裁；定义 `236C` 来源限定的特殊 `5D → 5B` token 何时取得、消费、清除。
2. **木桩防御**：确定性防御请求/训练设置的入口、木桩防御姿态持续方式、被防硬直/推退/停顿的字段和反击招式/距离；明确怎样分别验证命中、被防、挥空。现有玩家防御测试不能替代这一决策。
3. **位移、碰撞和换边**：确定每个 D 系动作的位移帧、垂直判定框偏移、身体碰撞/墙截断、实际穿过的判据，以及命中当帧结算和下一帧面向/方向候选锁定顺序。
4. **受击状态转换**：为 ground slide、低浮空、`j2D` 带地、`j214D` 弹地、`214C~B/~C` 和 `j6D` 普通落地连接确定状态名、计时、恢复事件、可追击资格、是否结束 combo 及同帧顺序；明确地面/空中 profile 的必填组合。
5. **落地例外**：精确定义 `j2D` 实际命中后何时可缓存/消费 `214C`，以及它与“所有落地恢复首帧锁、空技恢复全程锁”之间的专用例外关系；确认 `j6D` 只走恢复后的普通连接。
6. **弹地与循环边界**：确定触地、反弹、追击窗口和地面命中普通资料；明确 A 起手为何能命中但不能继续、B 级以上如何有限延长，并把规则接入不依赖全局命中数/时长上限的循环判据。
7. **修正模型**：确定首次有效命中的 A/B/C/D 起手锁定、伤害与时间/轨迹修正的独立公式、累计/舍入、跨状态是否保留和 A/B loop 的断开条件；确定这些字段进入 CombatSession 与 Solver 状态键的方式。
8. **初始帧表和验收范围**：为每招提供带单位的调校初值和版本，区分纸面初值、静态空间、真实击退回放和真人观察；确定中板/版边、左右面向、近远距离以及命中/被防/挥空的最小代表矩阵。

阶段 1 结束时应能回答这些问题，并把答案分别承接到 `decisions.md`、`frame-data.md`、`route-acceptance.md` 和后续 `spec.md`；在此之前不应重新实现已完成的 HitProfile、输入缓存、基础防御姿态或 Solver 静态空间层。
