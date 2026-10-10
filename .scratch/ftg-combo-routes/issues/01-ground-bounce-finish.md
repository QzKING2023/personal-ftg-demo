# 01：6A 对地起手，经弹地追击完成六击倒地

Status: ready-for-human
Type: AFK
Blocked by: None
实施状态：已实施并通过自动化验收与自审（2026-10-10，阶段 6）；剩余为待真人判断项（见 Completion evidence），体验验收未完成。

## Parent

- [本轮父规格](../spec.md)：R4-G、规则1/6/9/10/11、数值表及T1/T2/T4–T8；最新D决定优先。
- [原阶段9父票](../../ftg-character-implementation/issues/10-joint-acceptance-and-tuning.md)仅作历史来源，不修改、不关闭。

## User stories covered

- 12：6A对地挑空后完成独立六击基础路线。
- 14：双面向及明确近距离范围。
- 16：实际接地的D命中保留反应、横向受击速度归零。
- 17：5B对其他合法来源的普通低空目标具备显式命中能力。
- 18：再次有效命中可再次弹地，接续由真实时空决定。
- 20、22–24：失败解释、分层证据、保存恢复/Solver一致、诚实保留反例和未完成搜索。

## What to build

从地面中立开始，以预先固定的输入完成 `6A > jc > jC > j214D, 5B > 214C~C`，6个攻击动作、6 HIT，jc不算攻击，不插jB。首个6A命中未受击站立目标后合法跳消，jC/j214D命中、真实弹地，玩家完整落地恢复后5B普通连接，最终由Rekka派生造成首次实际普通倒地。终点前不得结束后重新起手，不附加换边或半板收益。

范围为双面向、身体横向边缘间距g连续[0,18]px、目标到起手时身后指定合法墙限的距离r连续[0,700]px；双方起手接地可行动、空输入历史/缓存、普通命中，无额外连段前缀。只取双方合法起点，一套G完整节奏跨区域，左右仅镜像方向。

本票一次交付下列共用行为；后续票复用并回归，不重新实施：

- 玩家与木桩身体、受击轮廓和外观由48×80改为12×20px，全场可见；q-body保留现有攻击框/间距/偏移、投距及未列运动值，不把攻击与运动统一缩为1/4。
- jC startup 7→4N，j214D startup 9→1N；j214D AIRBORNE normal/counter不可受身分别24/30→32/32N。
- 新增5B AIRBORNE normal/counter：LAUNCH、不可受身18/24N、水平60/向上100px/s；5B GROUND_BOUNCE的18/24→19/25N，反应与速度不变。精确资料匹配、缺失不回退、非法/重复键整表拒绝。
- 全部动作键D招式（包括蓄力与空中指令技）先验证命中资料与资格，再按本次反应施加前目标实际接地判定，将合法normal/counter HIT的水平受击速度置0并覆盖原惯性。保留反应、垂直值、计时与资格；接地slide/bounce适用、离地bounce不适用。BLOCK/WHIFF、缺资料、未开放追击及普通倒地不获得新命中能力。
- 取消B/C/D同连段一次弹地继续上限及A起手追击强制终点。再次有效命中的弹地反应正常生效；不刷新累计修正、空中资源，不增次数或全局命中/时长上限。A的slide负例重分类与D重复主验收归04，本票不把其旧预期误作弹地规则。
- 维持完整落地恢复及首帧锁；不新开空技落地后的稍晚等待。地面M资格、D停止/来源开放归03，6A新增空中资料归02。

所有变化同步资源校验、战斗行为、受影响训练呈现、保存恢复、共享Solver语义及正式帧表/说明，形成一个可演示的完整基础路线。这里只交付本票所需的统一方案子集；不得提前声称全D74方案或其他七个样本已通过。

## Positive and negative examples

- 正例：g0/g18、r0/r700、域内点及双面向均按G准确全链；端点邻域和非整数g/r补证，独立检查双方墙限及5B启动时恢复已结束。
- G参考（物理帧F）：6A F1–2、8跳消F11、jC F34、j214D末键F47、5B F78、214C末键F90、~C F114。214的末键前3/2/1帧依次下/下后/后，末键后+攻击；未列帧中立，单键1F后松开，左右镜像；6A首招仍为C等级。父规格的完整输入契约优先。
- 负例：6A被防/挥空无jc资格；错误jc或空中键时序、弹地触地前受身、5B恢复前或过晚、缺资料、非法重叠或越墙。不得用已有受击浮空目标冒充对地首击。
- 规则对照：普通浮空5B覆盖合法非弹地来源；全D normal/counter×接地/离地含slide/bounce；再次弹地与A/B/C/D起手分别记录，有限失败不能冒充次数硬门槛。
- 加入收尾前5C不是必保路线，保留缺airborne资料的诚实诊断，不给5C扩能力来消除范围外红灯。

## Acceptance criteria

- [x] 在上述保证域按完整六击、真实弹地、合法jc、完整恢复及首次实际普通倒地验收；保存输入、事件顺序、逐帧位置/高度和准确动作/HIT两种计数。
- [x] 范围验证包含端点、非整数和事件边界，说明覆盖方法与未覆盖部分；不把有限采样称数学穷尽。域内反例保存初态/输入/版本/首个失效事件，修正或按父规格回退，不能缩域。
- [x] 共用尺度、所有列明profile/时序及全D接地矩阵符合所选值；不新增资料回退、OTG、取消边或缩短恢复。
- [x] 多次弹地、A/B/C/D实际接续、自然恢复及有限性按真实行为取证；共享规则的Solver与真实空间回放分别报告范围、完整性和有效循环。超时/深度截止不等于无循环，发现无限有效循环须处置，不加硬上限。
- [x] 受本票影响的弹地状态/资格/计时在Hitstop、触地、消费与恢复边界保存续跑，与不中断回放逐事件和结果一致；Solver共享资料与资格，不把未知几何报为spatial-valid。
- [x] 扫关键键的连续成功闭区间并保留多处联合扰动计划/分母/断点；允许1F，旧7F及244/256不是门槛；脚本结果不代填真人成功率。
- [x] 阶段1事件边界回归保持；同帧HIT→END保留末击，END→HIT另列，终结HIT后允许自然落地取终点，不能补新命中改善结果。
- [x] 同步正式帧表、路线/训练说明及受本票影响的旧A弹地强制结束/一次资格预期，保留真正时空失败与历史日志。
- [x] 相关套件通过后执行当前推荐完整验收及未被编排的路线回放，检查退出码、脚本错误、断言和trace版本；本票问题消除且无新增失败，03所属历史失败继续单列。
- [x] 记录正式实施基线（本票为首票）、本票审查起点、实现/验证提交、实际命令、证据目录、自审结论及待真人项；实现完成与体验完成分别记账。

## Baseline ownership

阶段1 `air-full` 四击是通过证据，本票补齐规定Rekka倒地终点；`air-observe-5C`是范围外诊断，不是本票修复目标。阶段1的2+24条红灯均由[03的逐项台账](03-carry-long-short-routes.md)负责；本票不得删除/改绿它们，也不重复修复验收助手。

## Evidence and verification

- [父规格](../spec.md)、[设计最终摘要/D74/D80](../design.md)、[结果](../results.md)、[阶段1基线](../baseline.md)。事件修正提交`1bf00d587b90a2d0740eab0a651c8bb2d8283a7e`已经交付，工具10 PASS/0 FAIL。
- [E44核对](../review-e44-20261009.md)，实验`3e0ccc1`，对地26,638个整数起点支持G；[E45核对](../review-e45-20261009.md)纠正E44中立批次污染推断。采样不是连续域完成证据。
- [E18](../handoff-e18.md)、[E19](../handoff-e19.md)、[E20](../handoff-e20.md)只按各自参数栈理解规则方向；最终值以父规格为准，不原样移植实验子类。
- 实施入口按[工作流阶段6](../../../docs/combo-route-workflow.md)、[训练指南](../../../docs/training-guide.md)、[Solver指南](../../../docs/solver-guide.md)及当前工具帮助。完整入口：`python tools/run_acceptance.py --sweep --output <新的证据目录>`；单独确认本票路线回放已执行。症状对照：`python tools/run_combo_route_diagnostics.py --output <新的证据目录>`，旧诊断非零须按台账解释。
- [领域约定](../../../CONTEXT.md)及[ADR0002](../../../docs/adr/0002-natural-recovery-combo-rules.md)、[ADR0003](../../../docs/adr/0003-contextual-hit-profiles.md)、[ADR0005](../../../docs/adr/0005-special-reaction-states.md)、[ADR0007](../../../docs/adr/0007-solver-report-completeness-and-watchdog.md)约束自然截止、精确资料、特殊追击与报告完整性。

## Blocked by

None - can start immediately。规格已收敛，当前无未决设计问题。阶段6开始时重新记录工作树和实际实施基线；拆票时HEAD不能代填未来审查起点。

## Completion evidence

- **审查起点/实施阶段基线**：`2eebb175d86b4e378d9d1679bc8e73f543a411db`（拆票 HEAD，也是整个实施阶段基线——开工时工作树无其他代码提交）。实现提交：本记录所在提交（SHA 由其后的纯文档提交在 progress.md 回填）。
- **交付**：BODY_SIZE 12×20（头部/眼罩同比，攻击框/投距/运动值保留，墙限 30/930、ground_stand_y 470）；jC 7→4、j214D 9→1（恢复不变）；j214D AIRBORNE N/C 24/30→32/32；5B 新增 AIRBORNE N/C（LAUNCH 18/24、h60/up100）与 GROUND_BOUNCE 18/24→19/25；动作键 D 招式实际接地命中水平受击速度置 0（combat_session `_apply_player_hit`，按 action_key×dummy_on_ground，反应/垂直/计时/资格保留）；撤销 STARTER_BOUNCE_FOLLOWUP/combo_bounce_followup/BOUNCE_END——弹地目标命中自然接续、可再次弹地（多层修正不重置）；Solver PIN_DX=26、空间网格 12/24/44（44=5A/2A 判框远缘相切位）。
- **新测试**：`tests/test_ground_bounce_finish.gd`（52 断言：尺度、全 D 接地矩阵与例外面、BOUNCE_END 撤销、双弹地八击有限性、R4-G 参考路线双面向、3612 点保证域扫描（g 全整数×r 步长 35 + 边界行 r 全量 + 非整数样点，如实记录非穷尽）、六键 ±4F 连续区间、64 向量联合扰动、8 组负例）。
- **再锚定与回归**（12×20 几何 + 新选值，均为必要回归非重设计）：约 22 个既有套件距离/帧号迁移；A 起手弹地 5B 为 1F 目押窗（D72 允许 1F）；A 起手 juggle 以 jC 中介再挑空（6A 弹地 untech 17F 不够直接 j214D）；再弹地 6A 后 jc.jC 中介；j2D→214C 在 6D 换边后 214 指令按换边后面向镜像（世界方向 +原facing）；smoke/回放空中收尾 j5D→j2D（薄身下漂出触及）；test_solver_entry 的票据 08 dive 正例（垂直跳空中起始 jA→j6D）改记为如实负例（air_frames 0–37 全扫描挥空；俯冲在 launcher 语境由 test_air_d_landing/test_launcher_air_exits 承载）；test_solver_growth oracle 随已批准语义变更重生成（计数与 P1 基线逐字段一致，仅指纹轮换）。
- **命令与结果**：单套件开发期逐个运行（代表性全绿：test_ground_bounce_finish 52/0、test_bounce_corrections 78/0、test_hit_profiles 114/0、test_combat_session 852/0、test_combat_session_restore 102/0、test_move_table 329/0、test_replay_acceptance 123/0、test_solver_spatial 481/0、test_solver_entry 52/0、test_solver_checkpoint_trie 25/0、test_solver_growth（regen 后）全过、test_combo_solver 247/0）。完整验收：`python tools/run_acceptance.py --sweep --output .scratch/ftg-combo-routes/runs/full-04`（**35 job 全绿 exit=0，3811 断言，0 脚本错误，墙钟 347.7s**）。未编排路线回放：`python tools/run_combo_route_diagnostics.py --output .scratch/ftg-combo-routes/runs/impl01-sym/full-01`（boundary 10/0；replay10 99 PASS/2 FAIL 仅 J3b=BL01–02；symptoms 14 连续性失败=BL03–20 族）。注意：本票期间 full-03 首跑暴露 4 个本票再锚定缺口（combo_solver 空中路线 j5D 收尾、checkpoint_trie 变异阈值、growth oracle、spatial 网格文案断言），全部修复后 full-04 复跑；逐项证据在 runs/impl01-tdd/（entry.log、dive-diag.log、cpt-recheck.log、growth-regen.log、spatial-recheck.log、combo-solver-recheck.log）。
- **已知失败对照**：本票所属失败全部消除（票据 10 final-02 全绿的 33 job 中受本票影响者在 full-04 应全绿；四个 sweep 内新增失败已修复并复验）；03 台账 BL01–26 保留原归属——replay10 J3b 双面向 2 FAIL 与 symptoms 14 条连续性失败形状与基线一致；**10 条 ground-* 换边失败随 12×20 穿越几何自然消失**（6D 88px 位移在 12px 薄身下必然穿越换边，旧行断言不再可达；如实记录，03 实施时按新几何复核）。
- **自审**：Standards/Spec 双轴过查（实现 diff 逐文件复核：规则注释与票据口径一致、无钉位/跳恢复/新起手凑绿、负例保留、文档同步 move-data/training-guide/solver-guide/frame-data；combo_solver 报告文案中 14 处旧 48/64/80 网格残留已清）。发现并修复：move-data.md 旧 BOUNCE_END 段落、test_solver_spatial 遗漏网格断言。
- **待真人判断项**：R4-G 六击真人试玩（目押/节奏可行性，归 06）；J5 空中链尾部 jC 不可达边界的调校候选（原 D1/D2，随本票前移）；A 起手弹地 5B 的 1F 目押窗是否可接受（过窄则调校候选）；j5D 作为空中收尾对 26px 起手不可达（改用 j2D，视觉/手感差异）；jA→j6D 俯冲链在垂直跳空中起始不再成立（仅 launcher 语境可用）。
- **实现完成≠体验验收完成**：本票标记为已实施；真人体验验收按 06（HITL）另行执行。

## Comments

2026-10-09：用户确认六票拆分；本票按批准顺序创建。阶段5仅写票据，不实施正式功能。

2026-10-10：阶段 6 实施（本记录）。full-04 完整验收 35 job 全绿（3811 断言）；full-03 首跑的 4 个失败均为本票再锚定缺口、修复后 full-04 复跑全绿（逐项证据 runs/impl01-tdd/）。不自动接票据 02。
