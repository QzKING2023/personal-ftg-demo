# 票据 09 验收报告：j214D 弹地与跨状态循环边界

日期：2026-10-03。调校初值版本：frame-data v0.11（全部 TUNING_INITIAL）。
本票证据目录：`.scratch/ftg-character-implementation/acceptance/09/`。

## 交付物

| 层 | 内容 |
| --- | --- |
| 资源 | `data/moves/j214D.tres` 新建（9/4/22、伤 20、52×36 gap4、motion 12/64、SPECIAL 层）；jA/jB/jC cancel += j214D；6D/2D air_exit += j214D；5B/6A/214C 新增弹地目标键（LAUNCH 追击资料）；manifest 挂载 |
| Schema | `HitProfile.TargetState.GROUND_BOUNCE`（4）、`HitProfile.Reaction.GROUND_BOUNCE`（7）；MoveTable 校验扩展（枚举范围 1–4/1–7、弹地反应组合规则、弹地目标键不接受再次弹地） |
| 运行时 | `DummyState.GROUND_BOUNCE` 状态机（进入→触地前窗口→bounce_contact 反弹一次→统一追击窗口→自然回中立，不转倒地）；`BOUNCE_CONTACT` 事件与 `BOUNCE_END` 结束原因；弹地等待的空技延迟连接（触地开窗后评估，等待期缓存不被独立起手窃取） |
| 修正 | `STARTER_BOUNCE_FOLLOWUP`（A=0/B·C·D=1，GROUND_BOUNCE 进入时派生、成功追击消费、连段结束清除）；`BOUNCE_HIT_*`（0.88/0.92/0.93）与 `LANDING_LINK_HIT_*`（0.94/0.95/0.95）分层每击倍率；`move_via_air_link` 标记 |
| 训练场 | 弹地状态/触地注记/追击资格反馈、BOUNCE_END 文案 |
| Solver | 可追击域纳入弹地（仅触地后）、bounce 状态文本、SCOPE 地弹移入支持域并追加票据 09 扩展；settlement_state 携带 bounce_contact/bounce_left/bounce_followup/via_air_link |
| 测试 | `tests/test_bounce_corrections.gd`（83 断言）；`tests/acceptance_replay_09.gd`（R0–R2 双面向 + N1–N4）；test_smoke/test_move_table/test_hit_profiles/test_combo_solver 随表迁移更新 |

## 规格逐条对照（spec §3/§5 与票据 AC）

| 要求 | 结果 | 证据 |
| --- | --- | --- |
| j214D 对 grounded/airborne 都进 GROUND_BOUNCE，profile 分别声明进入运动、结果状态统一 | PASS | 单元「双入口资料」+ R0（grounded）/R2（airborne）；运行时 match 分支唯一 |
| 触地事件记 bounce_contact、开放追击；一次弹地最多一次反弹；不刷新空中资源；不转 OTG | PASS | 单元「恰一次 bounce_contact」「不转 KNOCKED_DOWN」；R0 全流程（触地→反弹→窗口→空中受身→落地中立）；N1 独立 5A 打不中弹地目标 |
| A 起手 bounce_followup=0：命中只作收尾；B/C/D=1 一次性消费 | PASS | R1（A 起手第 7 击 5B 命中当帧 BOUNCE_END）；R2（B 起手 6A 追击消费资格后 jc.jA 延长）；N3（后续命中不刷新资格） |
| starter grade 首击锁定、跨 slide/Rekka/bounce/落地保持；BLOCKED/MISS 不锁定；状态结束清除 | PASS | 单元「B 全程锁定 + 三层逐击核对」「slide 跨越 D 锁定」「Rekka 跨越 C 锁定」「被防/挥空不锁定」「BOUNCE_END 后 UNSET」 |
| 三层乘法累计、分层舍入、伤害 10% 底线、时/轨不套底线 | PASS | 既有 C-01/C-02 机制延续；新增 bounce/landing 分层逐击数值断言（0.84×0.9⁴×0.88×0.9 等） |
| 正例：B 起手触地后按剩余硬直接 5B/6A/214C | PASS | R2（6A）+ 单元（5B 消费资格）；214C 边由 Solver 枚举验证 |
| 反例：A 起手继续 / B 刷新 / 二次弹地 / 弹地当 OTG / 修正重置 | PASS | 单元 N 系列（A 起手 BOUNCE_END 后 5C 为新连段第 1 击；B 消费后不刷新；j214D 无弹地键→MISS_NO_PROFILE 且结构上不可达；独立 5A 无命中；跨状态 scale 连续） |
| 不用全局命中数/时长上限掩盖循环 | PASS | 循环判定沿用逐圈快照重现（观测上限 8 圈/2400 帧以截断/未完成如实上报）；修正衰减使逐圈状态必然漂移 |
| 236C>5D loop（A 起手）不成立 | PASS | 单元：A 起手 5A>236C(两段)>5D 后木桩自然受身，5B 只能作新连段第 1 击（票据 05 结论复验） |
| Solver 报告区分有限多圈/有效循环/未完成/not-supported | PASS（报告机制既有 + 键扩展） | settlement 键含弹地字段；全量 Solver 结果见下节 |

## Solver 证据

- 表级：默认表接续边 71 → **79**（ticket 09 +8：jA/jB/jC→j214D 取消 3、6D/2D→j214D 出口 2、j214D→5B/6A/214C 弹地延迟连接 3）。
- 静态图估算：≤8 节点简单路径 2383 → **4967**（1.8× 膨胀），初等环 421 → **1195**（2.8×）——空↔地回边（j214D→地面追击→6A jump cancel→空中→j214D）使环空间组合膨胀。
- **Solver 成本警示（本票重要发现）**：默认表单次 analyze（单面向）由票据 08 的 562s 涨至 **>35 分钟未完成即被终止**；带空间复验的 solve 单请求实测 **>5 小时**。全量验收由 53.28min（speedup 07 终证）膨胀至**小时级**——路线 ×1.8、初等环 ×2.8、空间网格复验三者叠乘 ≈15×。这不是缺陷而是图密度增长的结构性成本；「路线枚举预算或前缀复用（记忆化）」的推迟决定（票据 08 记录）在票据 09 后不再可持续，阶段 9 或后续票必须先处理，否则每票扩图都会复利放大验收时长。
- 循环结论口径：逐圈快照重现证明机制不变（观测上限 8 圈/2400 帧以截断/未完成如实上报）；修正衰减使逐圈状态键必然漂移，A/B 起手均不会把回边误报为有效循环；具体循环/未完成计数以全量运行 summary 为准（见下节回填）。

## 全量自动化

- **2026-10-05 `tools/run_acceptance.py --sweep`（pool 模式）→ [09-full-02/](09-full-02/)**：33 job 全过（每 job exit=0，无失败族）、**3896 断言**、总墙 **294.0s**；清扫 89 请求 = 87 complete + 2 已知重建门设计缺口（与 09-full-01 同源，热跑原地重算覆盖）；cache-merge 93 条（+6 新）。**4 个 solve+空间任务实际暂停续算（pauses=1）且 replay_ok=True**——暂停续算空间回归修复的在位证明。退出码 0。
- **09-full-01 尾巴修复记录**：09-full-01 唯一失败为 test_solver_spatial 3 FAIL——solve 级暂停续算把空间验证整段丢掉（`_solve_paused_return` 只改写快照顶层、未按 `_resume_solve` 的读取形态持久化 `thread` 载荷，续算腿 `spatial=false` 重算主面向，all-UNVERIFIED 路线经 worker `_sweep_store_completed` 入结果缓存，29 条 solve+空间缓存条目全部污染）。修复 + 回归测试 `test_solver_routes_cycles_refactor._test_interrupt_resume_solve_spatial`（反证：临时摘除修复，恰好「续算无缺验路线」「指纹全等」2 条断言 FAIL，其余全过）。验收尾巴的 36+ FAIL 在途族（9 套件，根因=79 边表扩容后 MAX_ROUTE_REPORTS=16 呈现上限触顶）经新增 `ComboSolver.route_report()` 精确路线查询改写后全部转绿。
- 环境健壮性顺带修复：首跑 09-full-02 在 42 任务后因 `_write_json_atomic` 的 Windows `os.replace` WinError 5（杀软/索引器短暂握住目标文件）崩溃，已加有界退避重试（6 次）。
- fingerprint 门：全 33 job 内置指纹断言 exit=0（P7 canonical 105c43c7 语义在本票改动下不旋转）。

## 回放证据（replay-bounce.log）

- R0 独立跳 j214D 对地（双面向）：F22 命中（D 起手 solo、资格=1）→F39 触地反弹（vy=-317=roundf(330×0.96)、窗 15=floor(16×0.96)）→恰一次触点→无追击输入收招未接续结束→自然回中立。
- R1 A 起手 5A>5B>5C>6A>jc.jB>j214D>5B（双面向）：七击 F6/21/38/54/75/93/119；5B F113 起手（落地恢复后首帧）、F119 命中当帧 BOUNCE_END。
- R2 B 起手 5B>5C>6A>jc.jB>j214D>6A>jc.jA（双面向）：七击 F10/27/44/67/85/116/136；6A 于触地开窗帧 F108 消费一次性资格、jump cancel jA 真实延长。
- N1 弹地窗口内独立 5A 无命中（非 OTG）；N2 A 起手过早输入过期（F99 按下在 F113 评估前过期，无追击起手、不伪造命中）；N3 资格不随命中刷新；N4 第二次 j214D 资料门（弹地目标键不声明，弹地追击资料仅 5B/6A/214C 持有且命中即离开弹地——二次弹地结构不可达）。

## 已声明交付边界 / 待真人（TUNING_INITIAL）

- 弹地速度 330、触地节拍（solo 命中→触地 17 帧）、追击窗 16、A/B/C/D 起手差异手感：待试玩。
- 弹地追击目押实际输入窗约 3–4 帧（B/C 组合等待 3f + 缓存 6f 夹挤）：容差待真人判断。
- 5B 弹地资料 untech 18 撑不满「追击后再链 5C」（差 2 帧）；延长正例由 6A（untech 30）承担——是否放宽属调校。
- j214D airborne 触地前窗 24 在深连段时间层（≤0.6）下为 14 帧：高浮空入口可用性随调校复验。
- 旧地面 214D 资源保留至阶段 9 统一迁移（与 j214D 分属不同姿态，无输入冲突）。
