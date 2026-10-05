# 连段工作流阶段 1：验收修正与症状基线

2026-10-05。阶段 1 完成；目标路线未修复，未启动阶段 2 或调参。

## 基线与范围

- 基线提交：`53a6c2f72d49757d915ef2659d98751563a4a7b6`。
- 起始工作树唯一既有改动：未跟踪的 `docs/combo-route-workflow.md`，保留原样，不纳入本次提交。无既有 tracked 修改，未清理来源不明文件。
- 修正提交见 progress.md；也可用 `git log -1 --format=%H -- tests/replay_combo_evidence.gd` 定位。
- 已读工作流“当前起点”、AGENTS、CONTEXT、tracker/triage/domain、相关 ADR 0001–0007、原角色设计/roadmap、spec/decisions/frame-data/route-acceptance、阶段 9 票据/report/coverage/playtest、训练场与 Solver 指南。
- 仅修改验收代码和事实文档。`scripts/`、`data/`、正式战斗规则、参数和 Solver 零改动。未重跑全表 Solver；本轮工具变化由快速真实 CombatSession 回放覆盖。

## 已执行的快速红灯命令

项目根目录执行，输出目录必须尚不存在：

```powershell
python tools/run_combo_route_diagnostics.py --output .scratch/ftg-combo-routes/runs/recheck-01
```

可加 `--case ground-full` 或 `--case air-full` 只选相应症状计划；工具回归和全部 replay10 仍执行。runner 对已知路线失败仍返回非零，同时检查脚本错误与完成标记，不把“已知”改成通过。

实际以 `verify-02`、`verify-03` 两个新目录执行了两次，均约 4 秒。各 summary.json 保存完整引擎命令、退出码、耗时、断言数及每份 JSONL 的 SHA256。

| 工作 | 两次结果 | 证明范围 |
| --- | --- | --- |
| boundary 工具回归 | exit 0；10 PASS，0 FAIL | 首次结束边界、同帧顺序、判定段/招式区分及真实调用 |
| replay10 全部既有路线 | exit 1；103 PASS，2 FAIL | J3b 双面向目标三击失败，断言保留 |
| 10 套固定计划 × 双面向 | exit 1；13 PASS，24 FAIL | 同组症状的多个对照，并非 24 个独立 bug |
| 确定性 | 20/20 JSONL SHA256 相等 | 两次逐帧字节相同，退出码与断言数也一致 |

原助手首次重跑 `logs/replay10-original.log`：exit 0，实际 105 PASS。新增实际调用回归修正前为 `logs/regression-red.log`：exit 1，`first combo excludes the fresh 5B after COMBO_ENDED` 失败。修正后早期 regression-green.log 为 9 PASS，最终补充相同 id 的不同动作不合并后为 10 PASS。旧报告的 93/106 不作当前套件计数。

最初执行命令（stdout/stderr 分别保存到 original/red 日志）：

```powershell
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . --log-file .scratch/ftg-combo-routes/logs/engine-original.log -s res://tests/acceptance_replay_10.gd
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . --log-file .scratch/ftg-combo-routes/logs/engine-regression-red.log -s res://tests/test_acceptance_combo_boundary.gd
```

早期相对 log-file 被引擎解释到 user://，出现日志目录错误；最终 runner 使用绝对路径和独立 APPDATA，已无该错误。环境证书库消息与无网络的回放无关；最终各 job 的脚本错误均为 0。

## 输入、位置与时钟契约

- inputs.json 行格式：`[开始F, 结束F, 水平轴, down, up, 动作键]`，闭区间。轴相对初始面向，运行前镜像为世界轴，不根据实时状态改变计划。
- 区间首帧按下动作/跳跃，随后仅保持；区间外释放。未列帧全部中立。JSONL 逐帧记录 pressed/held/released、世界轴、down/up/jump；方向释放由相邻帧可重建。B/C 组合等待、动作识别和缓存走正式代码。
- F0 玩家 `(240,440)`、木桩 `(290,440)`（右）或 `(190,440)`（左）；中心距离 50px，地面中立、无防御或攻击请求。全程保留真实位移、击退、碰撞和墙界；不钉位、不注入中间状态。
- F 为 60Hz 物理输入帧，首步 F1；N 为会话正常战斗帧，首个非冻结步 N1。8 个命中停顿帧只增 F、不增 N；命中帧正常结算。计划按 F，缓存年龄/硬直/招式恢复按 N。
- before/after 是帧首/帧末快照；events.order 是实际帧内顺序。不能以 after 的 combo_active、move_id 或修正值倒推每个事件瞬间。
- 快照包含双方位置/高度、木桩速度/状态/剩余硬直、招式帧/剩余自然招式帧、落地恢复、缓存/年龄/消费帧、方向历史/锁定、取消与来源资格、时间/轨迹修正、弹地触地/窗口/继续资格、位移锚点/已执行步、cross_ok 与墙截断。剩余招式帧不含未来 Hitstop，未提交蓄力仍可能延迟。
- 尾行 actions 记录启动及 charge_branch（包括挥空）；move_sequence 为首连段命中动作序列；hits 是逐判定段 HIT（frame/order/action/segment/combo_hits）；hits_after_end 单列首次结束后的全部 HIT。蓄力提交为同一次 D 动作换轨，不算两个攻击。

## 已验证事实：地面路线

### 完整路线

`ground-full`：`5B > 5C > 236C(段1) > 5[D], 5B`。236C→D 实际是特殊取消，D→B 才是恢复后普通连接。

固定输入：F1 B、F16 C；F30 下、31 下前、32 前、33 前+C；F45–60 按住 D（61 松）；F99 B。单帧动作下一帧即松，其他帧中立。

| 事件 | F / N | 结果 |
| --- | --- | --- |
| 5B、5C HIT | 10/10、27/19 | 第 1、2 击 |
| 236C 段 1 HIT | 42/26 | 第 3 击；段 2 被取消，不是漏记 |
| 蓄力提交、5[D] HIT | 59/35、60/36 | 第 4 击；取得 cross_ok 和特殊进入来源 |
| 最后位移步 | 71/39 | 玩家 x269.261、木桩 x317.672、高度7.38；未换边 |
| 首次 COMBO_ENDED | 89/57 | DUMMY_RECOVERED；D 仍在第29招式帧 |
| D 收招 | 93/61 | 目标已恢复4个正常帧 |
| 最后 5B HIT | 108/76 | 新连段第1击，不能补成原路线第5击 |

穿越不是未命中或没有许可：F71 帧首计划终点 x360，木桩 x≈317.261，横距42.739 < 身体宽48；高度差也 < 身体高80。`_commit_planned_step` 因终点重叠截回原侧 x≈269.261，cross_ok=true 也不豁免。墙未截断。D 命中前高度仅3px，位移段内最高约7.38px；这是低高度、累积水平距离与合法终点共同作用，不能概括成“增加高度必好”。

### 时间、缓存及段数对照

- ground-buffered 仅把最后 B 改到 F89：F92 缓存年龄3，F93 收招输出 LINK_FAILED(TARGET_RECOVERED)，B 不起手。有效缓存无法救原硬直不足。
- ground-early 仅改 B 为 F80：F85 年龄5，F86 消失，早于 F93 收招；这是独立的输入过早过期。
- ground-full-seg2 让 236C 两段命中：D 为 F58–75、B 为 F112。HIT F10/27/42/55(seg2)/73，四个命中动作产生五次 HIT，仍无换边；F101 自然恢复，F121 B 是新连段。不能把五 hit 叫五招连段。

### 最小复现

- 穿越缩为 ground-min-cross：删去最后 B，仅 `5B>5C>236C(段1)>5[D]`、观察到F100；四击通过，换边断言失败。
- ground-minus-5B 删除起手B并平移后缀：C/236C/D HIT F12/27/45，F56换边。ground-minus-5C 删除C并平移后缀：B/236C/D HIT F10/28/46，F57换边。因此在保留特殊进入D语义的删减范围内，两个前缀都影响穿越失败。单独236C成功不能替代完整B起手路线。
- 普通连接缩为 ground-min-link：`236C(段1)>5[D],5B`；F1–4 搓236+C、F16–30 D、F60 B。F13/31两击、F42换边；F64/N48 B已合法消费，目标余3f；F67/N51恢复，F70/N54 B命中为新连段。排除“只是按晚/只是没穿越”。去掉D或236C会离开该特殊来源普通连接路径。
- 这是保持来源语义的最小化，不声称穷举全部输入时序或人为起始状态证明全局最小；未修改数据或规则来制造最小例。

## 已验证事实：空中路线

air-full：`6A > jc > jC > j214D,5B`，四个攻击动作、四次HIT；jc不计命中。

固定输入：F1–2前+A；F14上跳、F15松；F23 C；F30下、31下后、32后、33后+D；F72 B。左右镜像一致。

- F9/N9 6A HIT；F33/N25 jC HIT，同帧后部取消进入j214D，不能把这一击记成帧末招式j214D。
- F50/N34 j214D HIT；F77/N53 BOUNCE_CONTACT，落地恢复已完成，缓存B在触地开窗帧消费；F83/N59 5B为第4击。
- 5B 消费一次弹地继续资格1→0，目标从GROUND_BOUNCE转为AIR_HITSTUN。资格耗尽不等于禁止所有普通后续；还须查显式边、profile、时序与空间。
- 没有后续输入时 F104/N72 DUMMY_RECOVERED结束。到5B为止没有断连；省略号未指定，不能宣称某个第五击失败，也不能擅自指定必保路线。
- air-observe-5C 仅加F86 C，是事实诊断分支：F92/N60合法起手5C，F100/N68 HIT_MISS。F100帧首高度12.99px、间距63.76px、硬直5f，帧末硬直4f；几何接触成立但5C仅有grounded profiles、缺airborne键，F104才恢复。仅加硬直或减击退不能解决这项profile缺失。
- 初始另一固定计划（jC F26、D F39、B F80）仅三击：j214D命中高度约83.5px，F81首次触地前受身，F89 B为新连段。见initial.log与初始trace归档；这是高度/触地前硬直负例，不冒充用户报告的四击。
- 成功帧表由有限静态计划校准得到：c∈[23,38]、d∈[c+10,c+24]、b∈[68,95]，每条从中立完整重放；首个结果c23/d33/b72，scan-air.log。没有读状态自动择机按键。一次性扫描源清理，最终输入永久保留。
- 没有已定义的第五击验收目标，所以保留四击前缀和明确标记的5C分支作为最小诊断；不把“无输入后自然恢复”当应修缺陷。

## 可证伪假设：复现后列出、逐项查证

| 排序/假设 | 可证伪预测 | 结果与边界 |
| --- | --- | --- |
| H1 身体终点约束使完整路线无法穿越 | 应有HIT/cross_ok、wall=false，最后计划终点落在48宽重叠区并被截回；删减前缀改变位置/修正可改变结果 | 完整与删减对照、`_commit_planned_step`吻合；未证明提高高度或位移就是获准修法 |
| H2 硬直短于恢复+5B前摇 | F89有效缓存也不能救完整路线；最短来源路线即使消费B也会先恢复 | 支持：完整F89恢复/F93收招；最短F64消费/F67恢复/F70命中 |
| H3 只是缓存或组合等待导致失败 | 将B放入有效缓存应保住原连段 | 唯一解释被否定；F89缓存有效仍失败。但F80→F86确有独立过期；空中F72→F77成功消费 |
| H4 弹地后目标状态不匹配后续profile | 候选5C应在有硬直且几何接触时HIT_MISS，而非根本未启动 | F92启动/F100 HIT_MISS及资源缺airborne键支持。资格耗尽不是该HIT_MISS的替代解释 |

## 推翻的旧结论与助手审查

1. J3b三击是假阳性：F64 MOVE_RECOVERED之后仍拼入F79新连段第1击。首次结束后的HIT永久单列；同帧按数组真实顺序解释。
2. 撤回“按住式蓄力进入余量足够，推翻票据06失败观察”。原J3b确能换边，但只有两击；完整B起手路线又不具备相同穿越几何。
3. “弹地5B后5C只差两帧，加untech即可”不充分；缺airborne profile可直接查证。历史09日志不改写，当前帧表/试玩表给出更正。
4. 旧事件日志使用step后player_move_id，会把同帧被取消的5C命中写成6A（J7A F38）、或jC写成后继。相关记录现使用结算前攻击身份；位置/修正仍是帧末快照。

已实际重跑所有通用助手调用：J1a/b、J2、J3a/b/c、J6、J6b、J7A/B、J8a/b、N3/N4/N5。只有J3b双面向目标断言转红；其余原断言保持。J3a为三招四hit；J7A/N5同帧HIT先于BOUNCE_END，终结击保留；逆序END→HIT也有专门回归。J4版边墙截断及J5原七击后的断连诊断仍通过，没有删断连检查求绿。

## 阶段 2 必须决定

- 保准确招式顺序，还是保“换边再延长/弹地再追击”体验并允许替代连接？两条省略号展开到何处？尚无答案。
- 第一条在236C哪一段后进入D，换边是必要结果还是条件收益；要保哪些起手等级、距离、版边和双面向条件？
- 弹地5B之后希望接哪招，5B及候选后续对普通airborne的职责，缺profile是有意限制还是待实现设计？不预选5C或6A为必保路线。
- D→B的时间余量、缓存容错、目押难度；是否重议身体终点约束和有限追击边界？阶段1不选参数。
- 后续实验分开比较高度、距离/合法终点、恢复/硬直、缓存、profile和继续资格；真人成功标准尚未制定。

## 证据保存

- 当前源：tests/replay_combo_evidence.gd、test_acceptance_combo_boundary.gd、replay_combo_routes.gd、inputs.json、tools/run_combo_route_diagnostics.py。
- 最终：runs/verify-02和verify-03的summary.json及boundary/replay10/symptoms.log；runs/determinism.json。
- verify-02四条主要右面向JSONL保留直接阅读（ground-full、ground-min-link、air-full、air-observe-5C）。其余逐帧记录无损归档trace-archive.zip，包含全部面向、删减、初始计划、两次复跑，条目保留原相对路径；每条首行自含当时输入。
- logs保留原助手、先红后绿、校准与中间运行输出。重复引擎日志和一次性scan_air.gd仅按本轮已知路径清理。
- 旧 `.scratch/ftg-character-implementation/acceptance/` 历史日志原样保留；只更正当前report/frame-data/票据10/playtest/training-guide/solver-guide。
