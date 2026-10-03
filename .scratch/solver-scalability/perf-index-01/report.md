# P1 交付档案：ComboSolver 不可变招式索引（perf-index-01）

日期：2026-10-03；分支 feature（票据 09 在途树之上叠加，机械等价变换，零语义变更）。
引擎：Godot 4.5.1 stable mono（`D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe`）。
每链独立 APPDATA（本目录 `appdata-a/b`），未设缓存/枚举环境变量。

## 交付物

- `scripts/combat/compiled_move_index.gd`：CompiledMoveIndex + 轻量 EdgeDescriptor。
- `scripts/combat/combo_solver.gd`：索引路径接入（_init 构建、查找映射、via 候选
  列表化、上下文待定名单轮进、配置边/缺口候选描述符化、staged 缺口接种）；
  旧路径以 `_compiled_index_disabled`（默认 false=索引启用）整体保留为差分
  oracle；语义签名收录新文件摘要。
- `tests/test_solver_index_equiv.gd`：双路径等价性差分门（结构常量防漂移、
  全语义指纹、报告序序列、形状冻结、恒等式、接种无残留、analyze 顺序敏感面）。
- `docs/solver-guide.md`：「不可变招式索引（P1）」节 + 增长基线口径更新。
- 本目录：证据运行日志与 `growth-index.json`。

## 索引结构（build 一次，之后只读）

| 结构 | 内容 | 消除的重复扫描 |
| --- | --- | --- |
| `start_keys` | id → 起手键（镜像 _start_key_for 规则） | 每调用 O(1)，替代逐次读表判型 |
| `charge_bases` | charge_move_id → 普通版（表序首中） | `_charge_base_of` O(N)→O(1)（fill 热路径反复调用） |
| `rev_cancel/rev_jump_cancel/rev_landing_cancel/rev_rekka/rev_air_exit` | to → 表序来源列表（谓词镜像各 `_context_via_*`，消费方仍逐谓词复验） | 上下文固点传播从「每轮×6 via×全表」降为「每轮×待定名单×候选」 |
| `context_pending` | 表序合格待定名单 | 固点循环不再每轮重扫全表 |
| `configured_edges` | 配置边描述符（from 表序 × kind 固定序 × 目标声明序，含蓄力派生） | `_analyze` 边循环的枚举推导一次完成，搜索序由数据结构承载 |
| `gap_candidates` | 缺口候选描述符（同上序；LANDING_CANCEL 结构死候选索引期剔除） | V² 对扫的谓词推导一次完成；落地死候选零探针成本 |

## 缺口探针：staged 接种替代逐候选深拷贝

旧路径每个缺口候选 `_table.duplicate()`（全表 dict）+ `MoveTable._fresh_copy`
（MoveData 深拷贝 + 配置数组重建）——默认表 2,002 次。新路径：同一 from 的候选
在枚举序中连续，换组时才深拷贝一份换入表项（每 from 至多一次，默认表 ~30 次），
组内候选只在副本上「追加目标/垫窗口 → 验证 → 精确回退」；组结束换回原对象。
调用方注入表与 manifest 共享表零可见写入（solve 入口本就克隆；analyze 注入表
的 canonical 文本前后全等由测试断言）。

## 复杂度变化

| 环节 | 旧 | 新 |
| --- | --- | --- |
| `_charge_base_of` | O(N)/次，fill 期间 O(边数) 次 | O(1) |
| `_build_contexts` | O(轮数×N×6×N) | O(轮数×待定×候选 + 建-index O(N+T)) |
| 缺口候选枚举 | 每请求 V² 对扫 + 每对 4-6 次数组 has | 索引期一次完成（V² 项保留——候选空间本身 Θ(V²)，消除的是重复推导） |
| 缺口探针表构建 | O(N dict + 深拷贝)/候选 | O(深拷贝)/from 组 + O(len)/候选回退 |
| 结构死候选 | 照付探针表成本后被 _build_edge 无条件拒绝 | 索引期剔除（唯一一类：LANDING_CANCEL 空→地缺口） |

计数口径微调：`structure_candidates`/`gap_built` 只统计实际进入探针的候选；
恒等式 `structure_candidates == edge_built + gap_built` 不变。

## 差分结果（全语义指纹，acceptance 口径）

| 对拍 | 结果 |
| --- | --- |
| 增长夹具 E=1/2/4/8 solve 双路径 | 指纹全等；edges/gaps 报告序逐条相等；context_attempts/edge_built/delay_dfs/prefix_* 全等；session_steps 全等 |
| 循环夹具双路径 | 同上（全地面表，gap_built 不变 28=28——落地死候选数为零的旁证） |
| analyze() 入口（表序枚举、顺序敏感）E=2 | 指纹全等 + 注入表 canonical 前后全等 |
| 默认表（62 招，rekka/charge/air-exit/命中落地全覆盖）solve 双路径 | 指纹 `e071fdc6…` 全等（= P0 基线指纹）；79 边/404 缺口/16 路线/0 循环逐项相等；v1 runs（edge 1110/gap 1672/leaf 165516）与 session_steps 2,114,250 全等 |
| test_solver_growth oracle 门 | 4 档指纹与 P0 入库 oracle 全等（8d8dd913/184a0b9c/5f5f21d3/d6a8e985），59 PASS 0 FAIL |
| test_solver_perf_profile（P0） | ALL PASSED |
| test_delay_prefix_restore（叶子级差分） | TOTAL failures=0 |
| test_solver_index_equiv（最终版） | 76 PASS 0 FAIL |
| test_combo_solver（生产回归） | 226 PASS / 11 FAIL——与 P0 基线同数；逐请求指纹 27/27 全等（compare_profiles.py），FAIL 标签集逐字相同（均为票据 09 在途既有） |
| test_solver_route（生产回归） | 541 PASS / 1 FAIL——与 P0 基线同数；逐请求指纹 15/15 全等，FAIL 标签逐字相同（71 边计数为在途既有） |

## 增长 profile（索引路径 vs P0 基线，solve 双面向合计）

| E | 结构候选(P0→P1) | gap_built(P0→P1) | 落地死候选数 | 其余形状量 |
| --- | --- | --- | --- | --- |
| 1 | 18 → 16 | 16 → 14 | 2 | 全等（edge 2/leaf 2/steps 1230/attempts 2） |
| 2 | 40 → 36 | 36 → 32 | 4 | 全等 |
| 4 | 120 → 108 | 112 → 100 | 12 | 全等 |
| 8 | 472 → 444 | 456 → 428 | 28 | 全等 |

## 默认表墙钟（单请求冷缓存，两次独立运行）

- 旧路径 224.0 s；索引路径 219.2 s（−2.1%）。
- 分区：gap_enum 4.30→3.61 s、edge_probe 4.17→3.27 s（探针表构建消除 +
  charge_base O(1)）；delay_leaf/route_walk（~215 s，叶子重放域，P0 管辖）
  不在本票范围——P1 是结构/增长票，不是默认表墙钟票。
- v2：gap_built 2002→1822（−180 落地死候选）、structure 2160→1980、
  context_attempts 48/48、session_steps 2,114,250/2,114,250、
  delay_dfs_leaves 165,506/165,506。

## 语义观察（记录，非歧义、未做任何「顺手修复」）

- LANDING_CANCEL 是「结构性恒拒」接缝：配置边照常枚举、照常入报告为固定
  理由的无效边（可见报告面，两边路径都原样保留）；缺口候选探针必然 null、
  零报告输出——只有后者在索引期剔除。代码注释明确这是现行规格（落地首帧
  无例外），非缺陷。
- `_gap_probe_table` 的 HIT_LANDING_CANCEL 窗口垫值（24）对缺口枚举不可达
  （命中落地取消不是缺口种类）——两条路径都原样保留该镜像，未删。
- 蓄力版来源「表序首中」：MoveTable 校验保证至多一个，注入表未校验时两
  路径同为首个命中——口径一致，无分叉。

## 复现命令

```bash
E=D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe
$E --headless --path . --check-only -s res://scripts/combat/compiled_move_index.gd   # 语法
$E --headless --path . --check-only -s res://scripts/combat/combo_solver.gd         # 语法
$E --headless --path . -s res://tests/test_solver_index_equiv.gd                    # 本票差分门
$E --headless --path . -s res://tests/test_solver_growth.gd                         # P0 增长/oracle 门
$E --headless --path . -s res://tests/test_solver_perf_profile.gd                   # P0 v2 观测
$E --headless --path . -s res://tests/test_delay_prefix_restore.gd                  # 叶子级差分
$E --headless --path . -s res://.scratch/solver-scalability/perf-index-01/default_dual_probe.gd  # 默认表双路径
PYTHONIOENCODING=utf-8 python .scratch/solver-scalability/perf-index-01/compare_profiles.py \
  .scratch/solver-scalability/perf-gate-01/precheck/combo-before.log \
  .scratch/solver-scalability/perf-index-01/combo-after.log                          # 生产回归对拍
```

## 未完成事项 / 后续建议

1. 默认表级差分（rekka/charge/air-exit 反向表的真实表覆盖）目前是 scratch
   证据运行，不是常驻测试门——常驻门若纳入默认表双跑会 +8 分钟验收时长；
   可考虑在 P2 决定是否以「小特征夹具」（rekka/charge/air-exit 克隆表）补齐。
2. `_table_summary_lines`/`_first_candidates`/`_binding_variant_lines` 仍是每
   请求一次全表线性扫——单次 O(N) 非热区，未索引化（避免为非热区扩索引面）。
3. V² 缺口候选空间本身保留（Θ(同姿态对数) 是语义事实）；进一步压缩需要
   「命中可达性」级别的静态预判，那会触碰「成立性由真实结算裁决」的边界，
   明确不做。
4. 墙钟大头（delay_leaf 122 s / route_walk 105 s）属叶子重放域——P0 已建
   v2 观测，后续票的攻坚对象在那里，不在枚举域。
