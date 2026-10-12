# E17 交接：旧 A 起手滑行负例在 D37 下的分类——2026-10-07

## 判词
- 负例重分类为两个独立事实：(1) 旧负例的固定输入复现属 **launch-loop 类**——5A>236C 双段接触几何下 SLIDE_STARTED 从不触发（slides 0 / seg1 hits 3，全臂；e0 末态 DUMMY_RECOVERED，ref 臂 MOVE_RECOVERED），其引擎是普通空中 launch loop（time 复利 0.7→0.658→0.61852），与滑行无关；(2) 结构上 **5A/2A>5A 起手根本没有滑行带**（17 距离 × 9 提交帧全扫：近=seg1 命中 launch，远=seg2 静默挥空）——能入滑的 A 系最小链是 5A>5B（A3），带宽仅 5px。
- 真实 GROUND_SLIDE 入口已证（SLIDE_STARTED + seg1 挥空 + seg2 命中 GROUNDED，前缀命中要求在位），带表面全 9 候选完全一致（提交帧口径、面向对称）：D 46..50@c4、A3 22..26@19、B 28..32@17、C 30..34@11、BC 20..22@26、A/A2 无带。
- 滑后选项（只分类不改数据；滑行数据全臂与 carrier 签名相等）：拾取窗 pickB [38,50] / pickC [46,52] / pickD [48,60]；蓄力 5[D] e0 [36,60] vs ref [27,60]（前提栈加宽）。**持续引擎只在 D 锚**：拾取循环周期恰 61F、梯深 6、联合抖动容差 ±1..2F；B 系循环几何脆弱（loopB-d2 e0 重滑 49,110，ref 臂失败——g28 位移近距几何，须按臂锁锚）。无拾取循环上限 2（loopnp D 周期 67F，距离漂移）；5B 桥接重滑：任何臂梯内为零；拾取后 5B 追击 ±14F 扫描 0 连接（solver 亦拒 5D→5B 边）——**有效循环数全臂有界**。
- 普通技 vs 滑行中目标：所有可达几何下**结构不可测**——中滑 5B ×5 时点 ×3 臂与 A3 近带普扫 12 行 ×3 臂全部零事件（纯空间挥空，无 HIT_MISS/data-missing 见证）；LOW_FLOAT_TO_SLIDE 期间缓冲普攻会把目标打起（触地前打断律），滑行不启动。晚 D=入口过期见证（d_action_entry=false，独立 5D 空中命中 F69）；seg1 被防=无资格；墙 gap0：全部带前缀入口翻转为 launch-loop，唯裸 D 仍滑且拾取 F43。
- 有限性（D34/D37）：solver 两臂 cycles=0 / incomplete=1 / paused=false（solve_ms 21163 / 22237，E15 口径）；[236C,5D] 路线验证通过（frames [13,18,25]），**全部 236C 循环查询被拒**。无无限有效循环。
- 前提栈整载 UNADJUDICATED（u56/g28+h22/p60/E18-la/E19-b|g/w32；k240 未载，E04/D03 已裁）：**入口表面不变**（带/窗/oldneg 判词全臂一致；臂审计 2085 门控行 0 违规、refb-refg 2094 行 0 违规、隔离 PASS n=9）；栈只改组合连击记账（e0 前缀眩晕先于 seg2 过期→seg2 合法重开新连击且滑行照常启动——local_ok=False ≠ 滑行失败；此假象曾在标定早期伪造「e0 无 A/B 入口」，已从锁锚判据移除）、蓄力窗宽度、与跨臂周期锚传递。
- 新变量族「236C 击倒尾」：**未命中**（追击 5B 不连接、solver 拒边、尾不可达），按题仅报告不展开。

## 复现
- 分支 `codex/combo-route-prototype-e17-20261007`（自 e16 头 aa17ba3），工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e17-20261007/ftgdemo`；实现+证据提交见分支头（prototype_e17/ 全部 TEMPORARY）。
- 命令链：`run.py --cal 1..4`（gap×c 扫）→ `build_cal.py`（按臂锁锚）→ `run.py --plans`/`parallel.py`（698 计划 ×9，并发 ≤4、独立 APPDATA）→ `analyze.py` → `isolation.gd` → `solver_leg.gd`×2 → `run.py --play --smoke` → `archive.py`。
- 证据：分支 `prototype_e17/evidence/`（20 文件含 manifest SHA256：9 套 metrics、summary/windows/headline、cal.json、arm-audit、isolation、solver×2、baseline-traces、diag 摘要×2）；原始 `runs/e17-*`（gitignored，含全部 plans/results JSONL 与 trace 抽样）。
- 基线无漂移：e17-baseline-before vs e17-diag-after——boundary 10/0（exit0）、replay10 103/2 已知、symptoms 13/24 已知、24/24 日志+trace SHA 全等。
- 试玩烟测：`--play --smoke` base__e0 exit 0 无错误。

## 提请设计聊天裁决
1. 旧负例作为**测试预期**的处置：基线数据从未支持「A 起手滑行循环」；若验收/台账有把该负例当数据存在的行，应按 D37 重标为 launch-loop 负例（本轮按并行写规则未动共享台账）。
2. 触地前打断律（LOW_FLOAT_TO_SLIDE 内被命中→改 launch、滑行不启动）是本轮实测的结构事实，E18/E19 族转换可能与之交互——是否立数据族条目。
3. 普通技 vs GROUND_SLIDE 全程零事件（无 HIT_MISS 见证）：若要遥测级 data-missing 资料条目属数据改动，E17 范围外。

## 待试玩
- D 锚 61F 拾取循环（裸 236C，gap 46..50）真人目押难度：提交窗 pickD [48,60] 宽 13F，理论宽松；循环节奏 61F 恒定，可试连打手感。
- B 入口（gap 28..32）单次滑行拾取 pickB [38,50]：确认近距滑行观感与 5px 入口带的实战容错（期望偏紧，仅核实观感）。
- 无需试玩 A 单起手：数据上不存在滑行入口（除非走 5A>5B）。

## 未竟
- 「236C 击倒尾」在实测锚不可达（追击 5B 零连接）——若设计上要求该尾成立，须先立 5D→5B 数据/空间前提（新题）。
- 普通技 vs 滑行的 contact 语义：引擎层面无见证可采，如需判定须数据改动（范围外）。
- 带前缀入口在墙角的全部翻转为 launch-loop 属空间事实；滑行在墙边的独走/择向手感未测（试玩项）。
