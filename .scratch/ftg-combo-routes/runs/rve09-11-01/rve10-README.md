# prototype_rve10 — RV-E10 方向 B：弹地/空中语境终缝构型探索（阶段 3 临时实验）

【临时实验代码】只存在于 `codex/combo-route-prototype-rve10-20261011` 实验分支，
绝不并入正式实现。零参数改动：不改任何正式资源/脚本/测试；全部证据来自对生产
CombatSession/FrameInput/MoveTable 的固定输入回放（引擎 v4.5.1-stable-mono）。

## 题目

RV-E02 已证：D97 原侧两轮普通 D 路线目标为**接地硬直**时，直接 `5B > 214C~C`
两缝不成立。本题在**保持前缀两轮 `5B>5C>236C(1)>5D` 不变**的前提下，在
5D#8（B 版）/5B#9（C 版）与终缝 `214C~C` 之间寻找能在未修改基线上建立
**空中/弹地语境**的连接段，使整条路线成立且满足 D97/D111（保位 0–12px、
玩家场内侧、零换边、KNOCKDOWN 收尾）。

## 运行环境

- 引擎：`D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path <本worktree> -s res://prototype_rve10/<脚本>.gd -- <args>`
- 并行进程需独立 APPDATA（`C:\Users\q1625\.codex\appdata-rve10-{a..f}`，已预建）。
- 新 worktree 首跑前需一次 `--headless --editor --path . --quit`（本分支已做，
  输出 `evidence-editor-init.log`）。

## 脚本

| 文件 | 作用 |
| --- | --- |
| `rve10_lib.gd` | 共享库：8 个候选构型定义、布点/输入构造、固定回放 `run()`、D97/D111 `verdict()`、层检查 |
| `rve10_probe.gd` | B/C 前缀逐帧状态探测 + 输入健全性（j214D/6A/跳消 jB） |
| `rve10_scan.gd` | 主扫描：逐层搜索固定输入计划；`cfg=/facing=/mode=ref|full|domain`，失败存首断诊断 |
| `rve10_matrix.gd` | 连通构型补强：`mode=window`（±12F 逐帧窗）`joint`（8 键 ±1 ×256）`negative`（OTG/错向/缺弹地追击负例） |

坐标约定：g=双方身体横向边缘间距（D106 域 [0,18]），r=目标身后到墙（[0,12]），
参考点 (9.3, 6.7, facing=1)。

## 结果一句话

8 个构型中 **C_air_ja** 连通：
`5C,236C,5D,5B,5C,236C,5D,5B,6A,jA,j214D,5B,214C,214C~C`（14 击）——
j214D 俯冲命中 6A 弹道顶点目标（玩家高 ~42px≤64px 可带落地）→ 目标 GROUND_BOUNCE
→ 地面 5B 弹地追击（窗末日）→ 214C 打再浮空目标 → ~C 接地硬直 KNOCKDOWN。
双面向 × D106 全域 27 点 + 2 域外对照 34/34 全过；零换边、倒地贴墙 0.0px、
玩家场内侧。终缝 ~C 单帧窗、联合 ±1 容差 17/256 —— 人性化属于设计裁决，
本票只存证（详见 `summary.md`）。

详细枚举表、逐构型死因、窗口/联合/负例数字与输入表见 **`summary.md`**；
原始证据在 `evidence/`。
