# prototype_rve10b — RV-E10b 派生实验（方向 2 参数变量 × C_air_ja 弹地构型）

**派生自 RV-E10×RV-E09，待设计追认。** 2026-10-11。分支
`codex/combo-route-prototype-rve10b-20261011`（自
`codex/combo-route-prototype-rve10-20261011` 分出）。

实验题（单一问题）：把 RV-E09 的参数变量（V1: 214C.startup 8→6；V2: 5B 接地
普通眩晕 14→17；V3b: 214C 接地普通眩晕 14→20；V4: 214C~C.startup 9→7）
施加到 RV-E10 的 C_air_ja 弹地构型上，能否使该构型达到 D112（每键 ≥3F 连续
单键裁决窗）/D113（联合 ≥231/256）？若不能，证明其紧缝中哪些与这些变量无关
（结构性），把方向 B（弹地语境构型）定格为对照/素材。

**结论速览：全部候选（菜单内 4 单变量 + 组合 + 菜单外派生小档）都够不到
D112/D113；b3/ja/jd/tc 四缝的裁决窗在所有候选下恒为 1F，属结构性。**
详见 `summary.md`。

## 环境

- 引擎：`D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe`（4.5.1 headless）
- 工作树：`C:/Users/q1625/.codex/worktrees/combo-route-prototype-rve10b/ftgdemo`
- 每个引擎进程必须独立 `APPDATA`（并发跑时尤其；曾致静默死亡）
- 参数注入缝：`CombatSession._init(move_table)`——候选表 =
  `MoveData.default_table()` 深拷贝后按令牌改字段；一进程一候选

## 重跑入口

首次在新工作树运行前先初始化编辑器缓存一次：

```bash
APPDATA="$(mktemp -d)" D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe \
  --headless --path C:/Users/q1625/.codex/worktrees/combo-route-prototype-rve10b/ftgdemo \
  --quit > prototype_rve10b/evidence/editor-init.log 2>&1
```

各脚本（`--` 后传参；证据写 `prototype_rve10b/evidence/`）：

```bash
ENG=D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe
WT=C:/Users/q1625/.codex/worktrees/combo-route-prototype-rve10b/ftgdemo

# Q0 基线复刻（默认表；8 键窗 + 联合 256 + 确定性）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_base.gd -- out=base-01.json

# Q1 单候选筛选（贪心锚重优 + 8 键窗 + 联合 scan_anchor/window_center + 均匀平移对照）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_screen.gd -- cand=V4
#   cand ∈ BASE V1 V1x V2 V3b V3bx V4 V4x（x=菜单外派生小档，仅对照）

# Q1 尾段联合重锚网格（排除贪心伪影；(b4,r2,tc) 耦合系统全枚举 + 每解 tc 窗）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_tailgrid.gd -- cand=V4

# 机制诊断（tc 逐日扫 + 目标逐帧状态转储）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_diag.gd -- cand=BASE

# 指定锚点 8 键窗（测候选在其解锚点上实际放宽了哪些缝）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_winat.gd -- cand=V1 b4=200 r2=217 tc=236

# Q2 门（V4 为最佳候选）：代表站位 / D106 域
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_domain.gd -- cand=V4 facing=1 mode=reps
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_domain.gd -- cand=V4 facing=-1 mode=reps

# 负例 N1–N5（V4 需带 tc=238 锚点覆盖；缺省用 BASE 参考锚）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_negative.gd -- cand=V4 tc=238

# 跨路线回归（R1/R2 搬运长短线 + R4-G 6A 对地，双面向 10 例；先 BASE 后候选）
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_regression.gd -- cand=BASE
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_regression.gd -- cand=V4

# Q3（限时）：B 起手弹地构型 B6A + 缝 A 变量 V2
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_q3.gd -- cand=V2 facing=1
APPDATA="$(mktemp -d)" "$ENG" --headless --path "$WT" -s res://prototype_rve10b/rve10b_q3.gd -- cand=V2 facing=-1
```

## 脚本清单

| 文件 | 作用 | 来源 |
| --- | --- | --- |
| `rve10b_lib.gd` | 合并库：构型/锚点/候选表/回放/裁决 | 改写自 rve10_lib.gd（5d563bc）与 rve09_lib.gd（560222e），头注有逐段归属 |
| `rve10b_base.gd` | Q0 基线复刻 + 确定性 | 骨架同 rve10_base |
| `rve10b_screen.gd` | Q1 单候选筛选 | 骨架同 rve10_scan/rve09_window |
| `rve10b_tailgrid.gd` | Q1 尾段 (b4,r2,tc) 联合网格 | 本轮新写 |
| `rve10b_diag.gd` | tc 缝机制诊断 | 本轮新写 |
| `rve10b_winat.gd` | 指定锚点 8 键窗 | 本轮新写 |
| `rve10b_domain.gd` | Q2 代表站位/D106 域 | 骨架同 rve10_domain |
| `rve10b_negative.gd` | 负例 N1–N5 | 语义照抄 RV-E02/E10 |
| `rve10b_regression.gd` | 跨路线回归 10 例 | 改写自 rve09_regression.gd，仅换库 |
| `rve10b_q3.gd` | Q3 B6A×V2 | 骨架同 rve10_scan 的 B6A 分支 |

所有脚本带 `【临时实验代码】` 语义头注；无 Solver、无正式资源改动、
无 HTML 原型、无另写战斗模型（CombatSession 真机回放）。

## 证据索引（evidence/）

- `base-01.json` / `base-02.json`：同参双跑，逐字节一致（确定性）
- `screen-{BASE,V1,V2,V3b,V4}.json`(+`run-screen-*.log`)：筛选 + 联合
- `screen-V4-run1.json` + 复跑 `screen-V4.json`：确定性逐字节一致
- `tailgrid-*.json`：8 候选尾段网格（BASE/V1/V1x/V2/V4/V4x/V1_V4/V2_V4）
- `diag-tc-{BASE,V4,V1}.json`：tc 机制（命中日-锁支窗-倒地日-状态转储）
- `winat-{V1,V1x}.json`：解锚点 8 键窗（V1 解 r2 仍 1F；菜单外 V1x 解 r2 9F）
- `domain-V4-f{1,-1}-reps.json`：代表站位 5/5 × 双面向
- `negative-V4.json`(+`run-negative-V4-tc238.log`)：N1–N5 双面向预期失败
- `regression-{BASE,V4}.json`：10/10 各
- `q3-V2-f{1,-1}.json`：B6A 推进到 jc 断（机制见 summary）

## 已知限制

1. V1 的贪心首遍锚定会落进伪影锚点（r2=205 → 214C 接触日提前 2F → 目标眩晕
   在空中耗尽 → tc 不可达）；须用 `rve10b_tailgrid.gd` 或 `rve10b_winat.gd`
   显式给解锚点（b4=200, r2=217, tc=236）才能观察 V1 真实行为。
2. 菜单外派生小档 V1x(214C.startup=7)/V4x(~C.startup=8)/V3bx(stun=16) 仅作
   对照，结果一律标注「菜单外档位」，不与菜单内档位混排。
3. Q3 按题限时盒：B6A×V2 断 jc 后记录机制即止，未穷举 jc 以外的替代构型。
4. 联合窗的 window_center 口径在本构型下低于 scan_anchor（1F 的 tc 缝使居中
   模板被拉离可用解）；两口径都已入档，权威口径=window_center（本题两口径
   都远低于 231，不影响裁决）。
5. 真人手感=待试玩，本轮不评估。
