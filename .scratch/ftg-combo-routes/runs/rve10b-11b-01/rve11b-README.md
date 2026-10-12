# TEMPORARY RV-E11b · 非 ~C 接地倒地终点（214C~B / 2C）以 ≤A 方案代价修复 D97 原版边（派生实验题）

【临时实验代码】仅存在于实验分支 `codex/combo-route-prototype-rve11b-20261011`（自 `codex/combo-route-prototype-rve09-20261011`＝`560222e` 切出，含 prototype_rve02/ 与 prototype_rve09/ 全套门槛/回归 harness 与 D97 路线锚点）。实验题 RV-E11b **派生自 RV-E11×RV-E09，design.md 未定义，待设计追认**：在 RV-E11 已证的接地语境帧算术下，非 ~C 的接地倒地终点（`214C~B`、`2C`）能否以 **≤ A 方案（V1+V3b+V4 三变量）** 的参数代价（更少变量或更小档位）使 D97 原版边两轮普通 D 路线（B/C 双起手，D103）连通且全门槛合格（D112/D113/D111/回归/负例）。本轮只回答这一题；D97/D103 已确认后缀仍是 `214C~C`，换终点属路线形状变更，全部产出仅作设计裁决证据，不代决。

## 结论速览（详见 summary.md）

- **两终点都存在 <A 代价的全门槛合格候选**：
  - **`2C` 终点：1 变量**——`Q19`（5B 接地 normal stun 14→19）或 `C6`（2C.startup 9→6），单变量同时修好 B/C 双起手；全门槛通过。
  - **`214C~B` 终点：2 变量**——`V1+P18`（214C.startup 8→6 + 214C 接地 stun 14→18）或 `V1+V3b`（A 方案前三之二，无需 V4）；全门槛通过。
- 结构机制（RV-E11 帧算术实测复核成立）：取消链命中=前击命中+8F 停顿+startup、rekka 派生命中=214C 命中 H+9+startup、恢复=H+8+眩晕_N；连通条件 2C 为 `startup(2C) ≤ 5B 末击眩晕_N`、~B 为 `眩晕_N(214C) ≥ startup(~B)+1`。floor 衰减（层_N=起手层×0.94^(N-1)）逐候选实测与推导一致，本轮无 floor 陷阱证伪。
- 副作用：四候选跨路线回归（R1/R2 长短搬运 ×B/C×双面向 + R4-G 六击，固定输入不重锚）**10/10 PASS**；`Q19`/`C6` 的 end/knock 帧号与 BASE 逐项相同（零漂移），`V1+P18`/`V1+V3b` 在 6 例 carry 上有小幅帧漂移（end −2F、knock ±1~+7F；V1 改 214C.startup 波及既有含 214C 路线，全部判据仍满足）；`C6` 只触碰 2C（既有路线不含 2C，天然零波及）。
- 语义差异（仅记录）：`214C~B` is_finisher=false（~C 为 true）；`2C` 经 LOW_FLOAT_SWEEP 浮空后触地转普通倒地（D93 口径算倒地，终点=触地转换帧，晚于 2C 命中约 15F）。
- 真人手感：**待试玩**（B 起手终缝窗恰 3F、预输入型 hit-5..hit-3，是否可执行须按 D114/D115 冻结候选试玩）。

## 复跑（PowerShell，仓库根 = 本工作树）

首次先初始化类缓存（新工作树必做）：

```powershell
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --editor --path . --quit
```

筛选与门槛（每候选一个引擎进程=零串扰；并行进程须各自独立 APPDATA；`cand` 组合令牌用 `+` 连接并加引号——传成下划线会落回 BASE 表，本轮已踩过并从 0/27 异常中定位）：

```powershell
$G='D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe'
$W='C:/Users/q1625/.codex/worktrees/combo-route-prototype-rve11b/ftgdemo'
# Q0 零参对照（复现 RV-E11 两断点）
& $G --headless --path $W -s res://prototype_rve11b/rve11b_screen.gd -- cand=BASE
# Q1 逐终点单变量/组合筛选（每个一个进程；例）
& $G --headless --path $W -s res://prototype_rve11b/rve11b_screen.gd -- cand=TB6
& $G --headless --path $W -s res://prototype_rve11b/rve11b_screen.gd -- cand=Q19
# Q2/Q3 门槛：D106 域 27 点 × kind × facing（4 进程）
foreach($kf in @('B 1','B -1','C 1','C -1')){ $a=$kf -split ' '
  & $G --headless --path $W -s res://prototype_rve11b/rve11b_scan.gd -- 'cand=Q19' ender=2c kind=$a[0] facing=$a[1] }
# 键窗 ±12（20 代表条件）、联合扰动（双模式）、负例、跨路线回归、终缝逐帧探测
& $G --headless --path $W -s res://prototype_rve11b/rve11b_window.gd  -- 'cand=Q19' ender=2c
& $G --headless --path $W -s res://prototype_rve11b/rve11b_joint.gd  -- 'cand=Q19' ender=2c
& $G --headless --path $W -s res://prototype_rve11b/rve11b_negative.gd -- 'cand=Q19' ender=2c
& $G --headless --path $W -s res://prototype_rve11b/rve11b_regression.gd -- 'cand=Q19'
& $G --headless --path $W -s res://prototype_rve11b/rve11b_probe.gd -- 'cand=Q19' ender=2c kind=C
```

`ender` 取 `rekka_b`（键 b3→r2→tb）或 `2c`（键 b3→e3）。四候选门槛套件：`Q19`/`C6`（ender=2c）、`V1+P18`/`V1+V3b`（ender=rekka_b）。

## 脚本与证据（prototype_rve11b/evidence/）

| 文件 | 内容 |
| --- | --- |
| `rve11b_lib.gd` | 共享库：终点感知路线/裁决/时序账目移植自 prototype_rve11（`git show codex/combo-route-prototype-rve11-20261011:prototype_rve11/rve11_lib.gd` 改写）；参数注入/站位/回归原语沿用 prototype_rve09；候选令牌 V1/V2/V3a/V3b 与 RV-E09 同名同值，新增 TB6/C8/C6/P15/P17/P18/Q16/Q19（逐招参数，D117 菜单内） |
| `screen-*.json/.log` | 候选筛选（B/C × rekka_b/2c 四组合逐层搜索，参考站位 g9.3/r6.7/f1） |
| `scan-<CAND>-<kind>-<ender>-f±1.json` | D106 域 27 点（含域外 (24,4)/(9,20) 对照）逐层搜索 + D97/D111 五项裁决 |
| `window-<CAND>-<ender>.json` | 终点相关键 ±12F 单键平移，20 代表条件，全链/层内双口径 |
| `joint-<CAND>-<ender>.json` | 256 冻结向量 × 8 条件 × 双模式（window_center 权威、scan_anchor 归档）+ 整条平移 ±1/±2 对照 |
| `negative-<CAND>-<ender>.json` | 终缝早/晚、删 b3、错向 214 指令块（rekka_b）/错形态无 down（2c）、OTG、镜像抽查 |
| `regression-<CAND>.json` | R1/R2 长短搬运 + R4-G 六击共 10 例固定输入不重锚 |
| `probe-<CAND>-<kind>-<ender>.json` | 终缝逐帧按压表（起点/命中/同连段/恢复日/倒地日）——静态帧算术对照 |
| `screen-Q19-rerun.json` | 确定性同参双跑第二份（与首份 `screen-Q19.json` 逐字节一致，`cmp` IDENTICAL） |

## 键组口径（与 RV-E02/E09 的差异说明）

- 8 紧接缝键组随终点换入终缝键：`rekka_b = {c1,m1,d1,c2,m2,d2,r2,tb}`；`2c` 路线无 r2，以 **b3 补位**保持 256 向量口径：`{c1,m1,d1,c2,m2,d2,b3,e3}`。b1 为起手不入组；b2/b3 属 M 等待链，2c 中 b3 是终缝直接前击故入组（rekka_b 中不入组，与 RV-E02/E09 相同）。
- 键窗测量键：rekka_b=`b3/r2/tb`、2c=`b3/e3`。
- 计划字典每帧一条输入：tb 探测/扫描范围自 r2+4 起（r2 指令块占 r2-3..r2），e3 范围自 b3+1 起（避开 b3 按压帧）——无 RV-E11 probe 曾出现的按压覆盖伪影。

## 已知限制

- B 起手终缝（tb/e3）与 r2/b3 全链窗恰 **3F**（同帧连通=零物理裕度，预输入型 hit-5..hit-3）：D112 进阶门槛（±1F=3 连续帧）按字面达标但**零余量**；联合扰动 window_center 模式 256/256 依赖参考点居中。真人可执行性待试玩。
- 负例 C 起手 `e3_late9`/`r2_late6` 实测仍过——与实测 12–13F 宽窗自洽（+9 未越窗），非语义破坏；与 RV-E09 对 C r2/tc 的同形记录一致。未补测恰好越窗的偏移（+13）。
- 单变量只连通 C 起手的候选（TB6/V3a/P15/P17/P18 于 ~B；C8/V2/Q16 于 2C）只做了筛选（screen），未跑全门槛——D103 要求 B/C 双起手同表必保，全门槛只在共享表候选（Q19/C6/V1+P18/V1+V3b）上取证；TB6+V1+P15 等 3 变量组合被 2 变量候选支配，未测。
- P15（214C stun 15）预测 C 起手 8N 同帧连通已实测成立（tb 9F），但它不修 B 起手缝 A，未列入正式候选。
- 被防/挥空对取消资格的 gating、A/D 起手路线回归、Solver/保存恢复一致性、对空混合判断不在本轮（与 RV-E09 同界）。
- 全部结论基于固定输入回放与上述采样域；连续域不作数学穷尽声明。B 起手全域不成立沿用 RV-E02 的 108 站位证明（缝 A 结构墙），本轮在参考站位与 D106 网格复现。
