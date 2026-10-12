# 阶段 F 综合审查报告（本轮功能交付增量）

日期：2026-10-12。审查者：功能交付流程阶段 F（$code-review，双轴）。流程：[combo-route-functional-delivery.md](../../../docs/combo-route-functional-delivery.md)。

## 固定审查范围

- **起点（解析为确定 SHA，非猜测）**：`df6110333418ecc8b923dbff21c3cf23d1f677c8`（`df61103`）。来源：progress E04 段记录的票据 04 审查起点（"本轮功能增量基线=生产 2C 9N 的 df61103"）；E06 返回提交 489d918 同记"阶段F综合审查（固定起点覆盖04/05实际修改）"。
- **结束提交**：`489d9184448fc360d114c393220a336b51b5d881`（HEAD，票据 06 阶段E前置核对返回，纯文档）。
- **范围内提交（5 个）**：`9932709`（04 实现：C6 落表+test_corner_two_d_finish+9 处再锚定+文档）、`bc94877`（04 回填）、`76cd97b`（05 实现：木桩跳跃训练请求+test_dummy_jump_practice+playtest.md+training-guide）、`ba23e41`（05 回填）、`489d918`（06 返回，含 issues/06 首次入库）。
- **工作树相关差异（未提交，属本轮阶段 A–D 增量，纳入审查）**：issues/01–03 阶段D追加段、progress.md 阶段D索引（+329 行）、CONTEXT.md 领域词汇（身后停止/贴身停靠/实际接地/板系列/妥协连/示例路线等）。`.scratch/solver-p5-01/resume-*.json` 为运行工件，不属功能交付面，排除。
- **合同来源**：[spec.md](../spec.md)（阶段 C 就绪版，D122 功能口径）+ 票据 [04](../issues/04-corner-two-d-finish.md)/[05](../issues/05-training-feedback-and-practice.md) 更新后正文；[design.md D120/D122](../design.md)。
- **Standards 来源**：AGENTS.md（tracker/triage 约定）、CONTEXT.md 词汇表、docs/agents/domain.md；仓库无 CODING_STANDARDS.md/CONTRIBUTING.md，另按 code-review 技能固定 smell 基线（repo 约定优先于基线）。
- **执行方式说明**：技能规定两轴以并行子代理执行；本会话无子代理工具可用，改为同一审查者按轴分离先后执行（先 Standards 后 Spec，发现不合并不重排），两轴结论仍分开呈现。此为执行方式偏差，不影响轴分离。

**范围覆盖核对**：`git diff df61103..489d918` = 25 文件 +2142/−154（2C.tres、combat_session/frame_input/main、project.godot、10 个测试文件、3 个 docs、5 个 .scratch 文档）；工作树差异如上。本轮全部实现提交（9932709/76cd97b）与文档提交均在范围内。01–03（c6d21a9/225a4e6/75d467e）早于起点，已有充分审查，本轮仅引用原证据（见"历史证据引用"）。

## Standards（仓库规范轴）

**结论：通过（2 项轻微发现，均已处置）。**

依据 AGENTS.md、CONTEXT.md 词汇表、domain.md（词汇使用/ADR 冲突）与 smell 基线逐 hunk 审查全部代码/测试/文档差异：

- **[T1] 死代码（judgement call，Speculative Generality）**：`tests/test_corner_two_d_finish.gd:522` `session_state_knocked()` 定义后无任何调用（文件内唯一引用即定义行）；注释称"保留的逐帧倒地查询"，实际逐帧倒地判断在两处 OTG 检查中内联执行。处置：删除该函数并复跑套件（见"修复与复验"）。
- **[T2] 文档错字**：票据 05 验收第 7 项"**実**際改动"混入日文汉字（実→实）。处置：订正。
- 符合项：代码注释携带票据/契约出处（票据 04/05 编号），与仓库既有风格一致；`FrameInput.make` 追加第 7 个可选参数延续既有 `dummy_move_request`/`dummy_guard_request` 增长模式（基线会标记 Data Clumps，但属已确立仓库惯例，予以抑制）；跳跃离地使用 `GameParams.jump_velocity()/PLAYER_MOVE_SPEED` 常量而非魔法数；`_motion_dummy` 增加一个守卫块但沿用该函数集中运动结算的既有结构；测试遵循姊妹套件 `_check`/PASS-FAIL 惯例；9 处再锚定测试均带 C6 出处注释。词汇使用与 CONTEXT.md 一致（身后停止、低浮空、命中确认取消、贴身停靠等无漂移）；无 ADR0006/0007 冲突（full-09/full-10 均以 `--sweep` 执行，语义签名轮换如实记录，无旧参数缓存复用）。

## Spec（规格/票据轴）

**结论：通过（1 项有效发现——票据 04 完成证据对红跑日志的引用数字失准，已订正；无功能缺口）。**

以更新后 spec 与票据 04/05 为合同，逐项核对：

- **准确八样本**：R3-B/C 套件 164 断言按冻结参考 v1 逐字复现（命中帧 B[10,27,42,58,83,99,114,130,153,167]/C[12,27,43,70,87,102,118,141,156] 与 spec/票据/阶段B frozen-inputs 一致）；R1/R2/R4 沿用 01–03 交付，full-09/10 全绿。playtest §1–§8 步骤表、镜像规则、参考帧表与套件常量逐项核对一致（R3 锚 1/12/29/45/74/79/100/117/143/149 与 1/15/31/61/71/89/105/132/143；R1-B/R1-C/R2/R4 节奏与 training-guide 行一致）。
- **结束边界/实际倒地**：首END=首次实际倒地同帧 KNOCKDOWN+LOW_FLOAT_LANDED（F181/F171）、原墙 0px、场内侧、post-END 命中另账、OTG 两组负例（两轮倒地后 F200 按 B 起身另账；浅层 5B 判定窗与 KNOCKED_DOWN 重叠无 HIT）——均在套件断言。
- **R3 保位**：`knock_wall∈[0,12]` 全域断言；域扫描 96 站位×B/C×双面向=384/384 + 触墙阈值邻点 r=2.1278/2.1279。
- **其他路线退化**：六样本路线均不含 2C（R1/R2/R4 序列核对），直接受 C6 影响的 2C 起手族（replay_10 J2/J8b、replay_08 R2、air_d_landing j6D、combat_session 三组 Rekka、restore _seq_rekka、bounce_corrections、combo_solver 2A>2B>2C、move_table）全部再锚定且带出处注释；combo_solver 的"诚实截断→三击成立 F6/14/21"为新事实断言，非语义削减；full-09（38/4201/0）与 full-10（39/4239/0）实读 summary 复核（tests 数、exit、断言总数逐一相符）。
- **同表条件收尾**：套件 `_test_r3_tails`/`_tail_box` 与票据 04 表逐数字一致（直接 2C 2/42、~B 3/43、~C 3/45；一轮 B 6/113、7/115、~C 正确形态 6HIT/END F115；C 一轮 5/101、6/103、F105>F104；两轮 149→10/181、142/143→9/171；两轮 ~B/~C 搜索盒双面向 0/609，B 首缝断/C 派生断；错误形态 5C 另列）；playtest §9 同表。
- **合法恢复**：D 段 51→75/123→147、36→60/111→135 完整恢复后 5B `via_link`；M 等待/预输入不绕过恢复；恢复前过早 5B（b2=60）负例在套件。
- **快照/Solver/缓存/循环**：R3-B 18 切点保存续跑逐事件等价；`dummy_jump_request` 已入 `_clone_frame_input`/`_restore_frame_input` 且请求帧/下落段两切点 clone→restore 等价有测；Solver/索引/缓存零 `dummy_jump` 引用（探针面零变化，full-10 冷算 519→525 无旧缓存复用）；D-loop 1–4 轮自然断点+第三轮时移 −40…+10 有限扫描如实记录，无"无循环"宣称；Solver R3 全序列钉位 refused 已知边界如实分列。
- **按键说明与真实行为一致**：实测核对 project.godot（动作 U/I/K/J、T=physical 84、跳跃 Space+↑、防御 G）、main.gd（HINT 文本、`_read_frame_input` T 接入、HUD `"%s[%s] 余%d帧"` 缓存显示格式）、GameParams（PLAYER_MOVE_SPEED=340、WALL_THICKNESS=24、中心墙限 30/930、BODY_SIZE 12×20、CENTER_MARK_WIDTH=6、出生 240/620）——playtest §0–§8 的键位表、±340px/s、6px 中心标记、出生位/间距/墙距（g≈368、r≈310）、墙厚与中心墙限全部与代码一致；物理 D≠动作 D 区分、236/214 按面向折算、镜像规则与 `_add_236/_add_214` 折算一致；§10 协议引用未执行、§11 空表无成绩、§12 原分母（jC 1F/0-64、jC[0,3]/5B[-2,0]/64-128、R3 单组窗）与票据记录一致。
- **[S1] 有效发现（证据引用失准，非功能缺口）**：票据 04 Completion evidence 写"TDD 红……症状与阶段B BASE 逐字吻合（**B 首END F188 前 9 HIT、C F177 前 8 HIT**……）"、Comments 2026-10-12 同写"（B 首END F188 前 9 HIT、**2C F190** 后另账；C F177/8……）"。实读 `runs/impl04-e01/red-run.log`：F188/F177 是**首END 后新连段 2C（F170/F159 另账）造成的实际倒地帧**（参考组 FAIL 行"实际 F188、0.000px"），**首END 实为 F167/F157**（9N 旧表对照 PASS 行"首END F167 仅 9 HIT"、line 2009/2011"2C F170/F159 是首END后新命中"）；"2C F190"在日志中不存在。结论方向不受影响（红跑确在 9N 生产真实失败、接续窗 [8,22]/[8,20] 实测吻合 line 2074–2075），但按"报告忠实、不抹掉失败证据"纪律，完成证据不得错引日志数字。处置：订正两处引用（见"修复与复验"），不改任何通过标准。

## 修复与复验

| 发现 | 处置 | 复验 |
| --- | --- | --- |
| S1 票据04红跑数字失准（首END↔倒地帧混标、F190 无出处） | 订正 Completion evidence 与 Comments 两段为日志实际值（首END F167/F157 前 9/8 HIT、2C F170/F159 另账、实际倒地 F188/F177） | 纯文档；订正后与 red-run.log line 3–31/2009/2011/2074–2075 逐字对应 |
| T1 test_corner_two_d_finish 死函数 | 删除 `session_state_knocked()`（无调用方） | 复跑 `test_corner_two_d_finish.gd` 全绿（164 PASS/0 FAIL，断言数不变） |
| T2 票据05"実際"错字 | 実→实 | 纯文档 |

按阶段 F 规则：本轮修复均为文档订正与测试死代码清理，**无功能行为改动、无新失败、无新疑点**，不重复完整冷跑 Solver/全量验收（最近一次 full-10 39job/4239 断言/0 失败仍为当前有效证据；测试文件文本变更将使下次全量的 Solver 语义签名按设计轮换冷算，属预期）。

## 历史证据引用（01–03，不重做）

01–03 实现提交 c6d21a9/225a4e6/75d467e 与 full-04/05/07 本会话实读 summary（35/3811、36/3869、37/4025，退出码均 0）；其原审查/验收记录在各自票据与 progress 保留，本轮无新增改动触及该范围（2C 不在六样本路线内；阶段 B 46 条固定输入 BASE/C6 逐字段相同）。BL01–BL26 唯一台账仍在 03；本轮诊断（impl04-diag-01/impl05-diag-01：boundary 10/0、replay10 99/2（J3b=BL01–02）、symptoms 24/13）与台账一致零新增。历史在途失败（replay_07 11 处、replay_08 R5×2、replay_10 J3b×2、symptoms 13）归 03 台账/历史脚本未再锚定，非本轮新增，维持原归属不重开。

## 限制与后置事项（按已落盘合同列示，不作为本轮阻塞）

- D112 窗口宽度/D113 联合 256 组：后置操作优化；playtest §12 原分母引用，未测项如实未测。
- D114/D115 真人练习与混合判断：归 06 未执行；playtest §10 协议引用+§11 空表。
- 0/609 搜索盒、第三轮时移扫描、域扫描 384 点：有限采样，不称连续域穷尽或任意时序无解；D76/D85 其余连续域点维持既有补验安排。
- Solver R3 全序列钉位查询 refused（钉位≠版边几何）：已知探针边界。
- 原阶段 9 父票据不改不关；本报告不声称真人验收完成。

## 两轴一行结论

- **Standards**：2 项发现（死代码 T1、错字 T2），最重为 T1——均已处置；轴结论通过。
- **Spec**：1 项有效发现（票据 04 完成证据红跑数字失准 S1），无功能缺口——已处置；轴结论通过。

本轮全部有效问题（S1/T1/T2）均有处置且复验在案；按流程可进入阶段 G（本阶段不自动接续）。
