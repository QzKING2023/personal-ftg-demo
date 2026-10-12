# TEMPORARY RV-E09 · 逐变量参数筛选修复直接 `5B > 214C~C` 后缀（D117 局部调校）

【临时实验代码】仅存在于实验分支 `codex/combo-route-prototype-rve09-20261011`（自 `5ada3ba` 切出，含 prototype_rve02/ 全套 RV-E02 证据），不并入正式实现。本轮只回答 design.md 的 RV-E09：保持通用输入规则（D117：通用缓存/指令识别/消费/Hitstop 不动），逐变量参数筛选能否同时修复 RV-E02 证伪的两条结构缝（B 缝 A=`5B#9→214C` 差 2F、缝 B=`214C→~C` 输入无解），并满足 D106/D110/D111/D112/D113。正式 data/scripts/tests 零改动——参数经 `CombatSession._init(move_table)` 注入，一进程一候选（进程级隔离=零串扰）。

## 结论速览（详见 summary.md）

- **单变量无一能同时修两缝**。实测缝 B 成立条件为 `214C 接地眩晕 N ≥ ~C.startup + 1`（~C 最早起手=214C 命中日 H+10、命中 H+9+startup；目标恢复=H+8+眩晕）。V3a（16N→C 8N/B 7N）与 V4（startup 7，需 N≥8）均差 1–2F，**反例报告的两条预测（V3a 修 C、V4 修 C/B）被实测证伪**——原因是 0.94^(N-1) 衰减的 floor 取整。
- **可行组合恰好两个（均 3 变量）**：`{V1+V3b+V4}` 与 `{V2+V3b+V4}`（缝 A 用 V1 或 V2 修，缝 B 必须 V3b+V4 同用：单独 V3b 差 1F、单独 V4 差 1F）。C 起手单变量 `{V3b}` 即可成立（供对照，不满足 B）。
- **两候选全部门槛通过且互相接近**：D106 域 27/27（含域外对照）× 双起手 × 双面向；键窗 B `b3 5F / r2 3F / tc 10F`（V1 组合）或 `3/3/10`（V2 组合）、C `7/13/11` 或 `7/12/11`，全部 20 代表条件逐帧一致；窗口居中参考下联合扰动 **256/256 × 8 条件**（D113 门槛 231）；负例语义与 RV-E02 全同；R1/R2 长短搬运与 R4-G 六击路线固定输入回归 **10/10 PASS**（不重锚）。
- 推荐与理由、参数可行性/真人手感分列见 `summary.md`；真人手感**待试玩**（本阶段无可试玩入口）。

## 复跑（PowerShell，仓库根 = 本工作树）

首次先初始化类缓存（新工作树必做）：

```powershell
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --editor --path . --quit
```

筛选（`cand` 取 `BASE`、单变量 `V1/V2/V3a/V3b/V4`、组合用 `+` 连接；每个候选单独一个引擎进程）：

```powershell
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve09/rve09_screen.gd -- cand=BASE
```

胜出候选完整取证（`<C>`=候选串，`_` 会替换输出文件名中的 `+`；并行进程须各自独立 APPDATA）：

```powershell
# D106 域网格（25 域内 + 2 域外 × 双起手 × 双面向，4 个进程）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve09/rve09_scan.gd -- cand=<C> kind=B facing=1
# 键窗 ±12（依赖 scan 输出）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve09/rve09_window.gd -- cand=<C>
# 联合扰动 256 × 8 条件 × 双参考模式（依赖 scan+window 输出）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve09/rve09_joint.gd -- cand=<C>
# 负例（依赖 scan 输出）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve09/rve09_negative.gd -- cand=<C>
# 跨路线回归 R1/R2 + R4-G（对照跑 cand=BASE 验证计划复刻）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve09/rve09_regression.gd -- cand=<C>
```

## 脚本与证据

| 文件 | 内容 |
| --- | --- |
| `rve09_lib.gd` | 共享库：rve02 口径的站位/计划/回放/裁决 + `cand_table()`（按 `+` 令牌深拷贝改字段：V1=214C.startup 8→6、V2=5B 接地 normal stun 14→17、V3a/V3b=214C 接地 normal stun 14→16/20、V4=214C~C.startup 9→7；接地 normal profile 按 `target_state==1 && hit_context==1` 定位）+ `place/run` 的候选表参数透传 |
| `rve09_screen.gd` → `screen-*.json` | 参考点 (9.3,6.7)/f1 的 B/C 逐层搜索：缝是否接通、b3/r2/tc 层内通过帧（裕度）、断点诊断（含 14 个候选） |
| `rve09_scan.gd` → `scan-<C>-{B,C}-f{±1}.json` | D106 域 27 站位网格 + D97/D111 完整裁决 |
| `rve09_window.gd` → `window-<C>.json` | b3/r2/tc ±12 全链+层内双口径连续区间（20 代表条件） |
| `rve09_joint.gd` → `joint-<C>.json` | 冻结 256 向量 × 8 条件 × 双参考模式（scan_anchor=扫描首遇锚 / window_center=实测窗中点重定 b3/r2/tc；另附整条统一平移 ±1/±2） |
| `rve09_negative.gd` → `negative-<C>.json` | r2 早/晚、tc 晚（Rekka 窗按正常帧计龄）、删 b3 无资格、倒地后 5B OTG（按命中帧 dummy 状态判定）、镜像抽查 |
| `rve09_regression.gd` → `regression-*.json` | R1/R2 长短搬运（计划照抄 tests/test_carry_long_short_routes.gd::_route_plan 含蓄力 D 按住）g2/r666、g2/r100 双起手双面向 + R4-G（照抄 tests/test_ground_bounce_finish.gd 常量）g2/r350 双面向；输入不重锚 |
| `rve09_seam_diag.gd` → `evidence/seam-diag-B-*.log` | 缝 B 逐帧机制证词（HITSTOP/锁分支/起手/命中/恢复逐帧） |

## 已知限制

- 计划字典每帧一条输入：方向指令块与按键同帧会互相覆盖；搜索锚点均避开碰撞（与 RV-E02 同）。
- 联合扰动 `scan_anchor` 模式对 B 只反映"扫描首遇锚落在窗缘"的参考选择伪影（V1 组合 128/256、V2 组合 64/256），非候选内在性质；`window_center` 模式（256/256）为实质门槛数字，两者都如实保存于 joint JSON。
- 负例未覆盖被防（沿用 RV-E02 边界，归后续回归）；RV-E09 边界清单中的 Solver/保存恢复一致性、A/D 起手回归、对空混合判断不在本轮（阶段 3 单题口径）。
- 真人手感未测：两候选均为参数改动，无新输入模式，待设计裁决后按 D114/D115 试玩。
