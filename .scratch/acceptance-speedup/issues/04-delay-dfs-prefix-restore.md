# 04: `_delay_dfs` 前缀快照恢复与逐叶子差分门

Status: implemented
Parent: [spec.md](../spec.md)
Blocked by: 03

## What to build

把已过差分证明的 CombatSession clone/restore seam 接入延迟搜索:`_delay_search` 在首个可调链接最早生效帧之前做一次前缀快照(会话状态 + 求解器侧全部循环内计数器),此后每个延迟向量叶子 restore 快照、只喂该叶子的尾部输入,不再从 frame 0 全量重放。配套逐叶子差分 harness:样本链上新旧两条路径并跑,完整 run dict 逐项相等,外加变异验证。搜索语义(字典序枚举、budget 按叶子计数、proof_mode 逐圈快照、首条成立即返回、失败代表性排序)一行不动——这是 ADR-0006 的红线。

## User stories covered

9, 10, 11, 12, 25。

## Acceptance criteria

- [x] 快照点 = 首个可调链接最早合法生效帧之前;恢复内容覆盖会话 clone_state 与求解器侧 frame/physics/verified/失败原因积累/循环快照序列/ended 计数——`_run_schedule` 循环内全部跨帧可变状态的清单在实施时逐项核对并记录。
- [x] 每叶子的尾部输入按该叶子延迟向量重新编译;与 proof_mode(逐圈快照)和 unpredicted_tail(尾部放行)两种模式均兼容。
- [x] 差分 harness:覆盖路线模式与 proof 模式的样本链,新旧路径并跑,逐叶子比较完整 run dict(ok、break_kind、break_reason 文案、verified、hit/extra 序列、snapshots、proven_period、laps_observed);叶子访问顺序一致(字典序)。
- [x] 变异验证:至少两个不同快照字段分别故意损坏,均被 harness 抓到(先例:seam 差分测试的两轮变异)。
- [x] 定向回归门:test_combo_solver、test_solver_route、test_solver_cycles、test_solver_spatial、test_solver_entry 与 02 基线 fingerprint 集合、断言计数逐项相等。
- [x] 03 profile 中最差请求的前后耗时对比记录在案(预期延迟叶子类耗时大幅下降;若不降,先解释)。
- [x] 隐藏回退开关(harness 专用,强制旧路径)仅测试可见,不进验收参数。

## Blocked by

- 03

## Comments

### 实现机制（2026-10-02，代码见 combo_solver.gd）

- **快照点（AC#1）**＝首个可调链接最早合法生效输入帧之前（含其方向喂入帧）。边界判定是纯编译期差分：可调链接全部取最早合法等待（JUMP_FRAME=1、PREV_HIT=0）编译基线表，再只把首个可调链接 +1 编译对照表，两表的**首个输入差异帧**即边界（`_first_input_difference`，`_freeze_input` 口径逐帧比值）——边界之前的部分对全部延迟向量不变，不需要任何运行时探测；编译冲突或边界不可判定时返回空表，叶子回退 frame 0 全量重放（正确性优先，只损失提速）。
- **捕获**：基线表经 `_run_schedule` 的 `capture_before_frame` 钩子重放到边界前一刻（复用原循环本体，零逻辑复制、零漂移），在步完边界前一帧并完成当帧事件处理（命中验证/断链分类/ended 记录/快照）后快照全部循环状态。基线区间内断链/证明成立时，断点先于任何可调输入、对延迟不变——全部叶子返回同值 run（frozen），仅 compiled/hit_frames/next_expected_move 按本叶子编译表替换（与旧路径逐叶子返回值逐字段一致）。
- **恢复（AC#2）**：每叶子 `_new_session`（恢复路径跳过空中起始探针序——restore_state 覆盖全部可变状态，seam 差分的 dirty-restore 口径证明任意前态下恢复等价）+ `restore_state`（clone_state 全量键）+ 求解器侧计数器复位，从边界帧起只喂本叶子按其延迟向量重新编译的尾部输入（循环内 `inputs` 字典天然只被 ≥ 边界的帧查询）。proof_mode（snapshot_every>0）与 unpredicted_tail（尾部放行 + extra 命中记录）两模式经 harness 直接对拍兼容。
- **`_run_schedule` 循环内全部跨帧可变状态清单（逐项核对）**：
  1. CombatSession 全部可变执行状态 → clone_state/restore_state（seam 差分已证，`CombatSessionState/v1`）；
  2. `frame` 正常帧号 → `prefix["frame"]`（＝边界−1）；
  3. `physics` 物理帧计数（max_frames 观测上限判据）→ `prefix["physics"]`；
  4. `verified` 已验证命中数 → `prefix["verified"]`；
  5. `break_reason`/`break_kind` → 前缀区间断链/证明时经 frozen_run 整体承载（值不变）；
  6. `ended_reasons` COMBO_ENDED 累积 → `prefix["ended_reasons"]`；
  7. `snapshots` 循环快照序列（[帧, settlement_state]）→ `prefix["snapshots"]`；
  8. `proven_period`/`laps_observed` → prefix 同名键；
  9. `extra_hit_frames/moves/counts`（unpredicted_tail 记录）→ prefix 同名键；
  10. `inputs`/`hit_frames`/`hit_moves`/`total`/`last_frame` → 每叶子从其编译表重建（尾部输入重新编译）；opts（snapshot_every/max_frames/unpredicted_tail/tail_frames）只读，`delay_budget` 仍由 `_delay_dfs` 语义不变地管理。
- **语义冻结（红线，一行未动）**：字典序枚举、`_delay_caps`、budget 按叶子计数（捕获探测不计 run——`delay_leaf_runs` 与旧路径逐叶相等）、proof_mode 逐圈快照、首条成立即返回、失败代表性排序。搜索语义之外的唯一行为差＝恢复叶子不再从 frame 0 重放，run dict 值不变。

### 差分 harness（tests/test_delay_prefix_restore.gd，AC#3/#4）

- **先证自洽（stage-a，先于恢复路径验证）**：旧路径双跑逐字节相同；比较器对损坏录制（verified 计数、断链文案）敏感。
- **样本**（表序发现，确定性）：jump cancel 链（深度 2 连通、深度 4 过伸）、单可调链接、proof 模式（snapshot_every=2，**369 叶全枚举**）、显式空中起始（air_frames=5，**64 叶**，覆盖探针序跳过路径）、超远钉位（480 px）构造的**前缀区间断链 frozen 短路**（64 叶）、unpredicted_tail 直接对拍（恢复 run == 全量重放 run）。
- **结果**：全部叶子 delays 向量序（＝字典序访问序）与完整 run dict 投影（ok/break_kind/断链文案/verified/hit 与 extra 序列/snapshots/proven_period/laps_observed/last_frame/末态 settlement_state）逐项相等；**34 PASS / 0 FAIL，0 SCRIPT ERROR，exit 0**（证据 `../delay-dfs-04/harness-evidence/harness.log`）。
- **变异验证×2（AC#4，先例＝seam 两轮变异）**：前缀快照内会话状态字段 `combo.hits`+1 与求解器侧计数器 `verified`+1 各损坏一次，均被逐叶子差分当场抓到（`_test_prefix_mutator` 钩子注入）。

### profile 前后对比（AC#6；同二进制经隐藏开关切换、结果缓存禁用、无争用、零 SCRIPT ERROR；证据 `../delay-dfs-04/profile/`）

| 请求 | 路径 | 墙钟 | delay_leaf | runs | 报告指纹 |
|---|---|---|---|---|---|
| solve-default（03 最差请求同级） | legacy | 1,046 s | 1,020 s（97.5%） | 351,196 | 154f2e62… |
| solve-default | **restore** | **535 s** | **512 s** | 351,196（相等） | 154f2e62…（相等） |
| analyze-default | legacy | 473 s | 461 s | 175,598 | dcc75f86… |
| analyze-default | **restore** | **264 s** | **253 s** | 175,598（相等） | dcc75f86…（相等） |

- 与 03 归档同形（legacy solve 1,046 s / 97.5% / 351,196 runs；03 采样 1,169 s 系争用膨胀，裸机口径吻合；两次会话的 legacy 各跑一遍分别为 1,093 s / 1,046 s，同量级）。**最差请求 delay_leaf 1,020 s → 512 s（1.99x），请求墙钟 1,046 s → 535 s（1.96x）**；analyze 1.82x / 1.79x。runs 与指纹全等＝零语义影响的直接证明。
- **收益边界说明**：本票机制＝单一共享前缀（按票据规格，一次快照），前缀只覆盖首个可调链接之前（样本链典型 ~15 帧），路线调度的其余帧（多个空中段＋落地＋地面链接）仍在每叶子重放——收益上限即前缀占比；基线区间断链/证明成立时整棵子树以 frozen 同值短路（这部分是全额节省）。继续压榨需逐深度嵌套前缀（DFS 每层共享更长前缀），超出本票范围，属 05 类条件追加票——04 后剩余大头仍是 delay_leaf 的尾部重放，若 06/08 后全量仍不达 ≤1h，可据此立项。

### 实现期两处缺陷与门的捕获（2026-10-02，留档）

定向回归门在实施期抓到两处缺陷，均修复后重跑——留档以说明门的灵敏度与语义冻结红线的执行：

1. **frozen 分支键名笔误**：`_capture_delay_prefix` 判定"探测在前缀区间断链/证明成立"时写了 `probe_run["break_reason"]`——run dict 的实际键名是 `reason`。缺键访问在 Godot 4.5 会打印 SCRIPT ERROR 并中止所在函数：捕获返回 null → `_delay_search` 整体回退旧路径（结果正确、提速丢失），但错误行被验收失败谓词计为 script_errors → test_solver_entry 门红（exit=1、指纹序列错位、solve-7 runs 缩水——错误级联中止了部分路线走查）。修复：键名改 `reason`。
2. **`_new_session` 探针序跳过极性写反**：`_new_session(prefix == null)` 把"prefix 为 null（旧路径/捕获探测）"误判为"应跳过空中起始探针序"——**全部旧路径 2 参调用**的显式空中起始会话从地面状态起跑，空中招式全部 no_start（干净 HEAD worktree 对照：routes=5 含 dive 链，带缺陷树 routes=0；新旧两路径同坏，故 harness 与 solve 级对拍都"相等"——这正是 harness 先证自洽仍需回归门兜底的教训：两条路径共享同一缺陷时逐叶子对拍无法发现）。修复：`_new_session(prefix != null)`——仅恢复叶子跳过探针序（restore_state 覆盖全部可变状态）。

修复后验证：空中起始 solve 两路径报告全文 identical（routes=5 含 jA→j6D hits=[5,12]）；harness 34 PASS / 0 FAIL / 0 SCRIPT ERROR。

### 定向回归门（AC#5，2026-10-02 PASS；证据 `../delay-dfs-04/gate/`）

5 个 Solver 定向 job 并行重跑（各自独立 APPDATA；`compare_jobs.py` 对 02 串行全量基线逐字段对拍）：

| job | 断言（PASS 行） | 指纹 | *_runs | exit | solver 耗时（02 基线 → 本票，含 5 路并行争用） |
|---|---|---|---|---|---|
| test_combo_solver | 3714 = 3714 | 11 条逐一相等 | 全等（delay_leaf 4,641,148） | 0 | 16,621 s → 6,828 s（**2.43x**） |
| test_solver_route | 2339 = 2339 | 8 条逐一相等 | 全等 | 0 | 8,595 s → 4,552 s（1.89x） |
| test_solver_cycles | 30 = 30 | 7 条逐一相等 | 全等 | 0 | 9,605 s → 4,732 s（2.03x） |
| test_solver_spatial | 11192 = 11192 | 6 条逐一相等 | 全等 | 0 | 4,233 s → 2,249 s（1.88x） |
| test_solver_entry | 53 = 53 | 6 条逐一相等 | 全等 | 0 | 1,815 s → 943 s（1.92x） |

五 job script_errors 均 0、GATE_OVERALL_EXIT=0；`*_ms` 为测量值只报不比。**Tier A 同模式对拍全绿**：指纹、断言计数、`*_runs`（搜索形状）、combo_cache 与 02 基线逐字段相等——提速未改变任何验收结果。五 job solver 耗时合计 40,869 s → 19,304 s（2.12x，含并行争用的保守值）。

复现：`../delay-dfs-04/run-gate.sh`（5 job 并行 + compare_jobs.py 汇总，gate.status.txt=0）。
