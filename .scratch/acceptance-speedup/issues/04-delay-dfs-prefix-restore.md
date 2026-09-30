# 04: `_delay_dfs` 前缀快照恢复与逐叶子差分门

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 03

## What to build

把已过差分证明的 CombatSession clone/restore seam 接入延迟搜索:`_delay_search` 在首个可调链接最早生效帧之前做一次前缀快照(会话状态 + 求解器侧全部循环内计数器),此后每个延迟向量叶子 restore 快照、只喂该叶子的尾部输入,不再从 frame 0 全量重放。配套逐叶子差分 harness:样本链上新旧两条路径并跑,完整 run dict 逐项相等,外加变异验证。搜索语义(字典序枚举、budget 按叶子计数、proof_mode 逐圈快照、首条成立即返回、失败代表性排序)一行不动——这是 ADR-0006 的红线。

## User stories covered

9, 10, 11, 12, 25。

## Acceptance criteria

- [ ] 快照点 = 首个可调链接最早合法生效帧之前;恢复内容覆盖会话 clone_state 与求解器侧 frame/physics/verified/失败原因积累/循环快照序列/ended 计数——`_run_schedule` 循环内全部跨帧可变状态的清单在实施时逐项核对并记录。
- [ ] 每叶子的尾部输入按该叶子延迟向量重新编译;与 proof_mode(逐圈快照)和 unpredicted_tail(尾部放行)两种模式均兼容。
- [ ] 差分 harness:覆盖路线模式与 proof 模式的样本链,新旧路径并跑,逐叶子比较完整 run dict(ok、break_kind、break_reason 文案、verified、hit/extra 序列、snapshots、proven_period、laps_observed);叶子访问顺序一致(字典序)。
- [ ] 变异验证:至少两个不同快照字段分别故意损坏,均被 harness 抓到(先例:seam 差分测试的两轮变异)。
- [ ] 定向回归门:test_combo_solver、test_solver_route、test_solver_cycles、test_solver_spatial、test_solver_entry 与 02 基线 fingerprint 集合、断言计数逐项相等。
- [ ] 03 profile 中最差请求的前后耗时对比记录在案(预期延迟叶子类耗时大幅下降;若不降,先解释)。
- [ ] 隐藏回退开关(harness 专用,强制旧路径)仅测试可见,不进验收参数。

## Blocked by

- 03
