# 恢复路径与叶登记复核验收

日期：2026-10-04

## 结果

- 恢复路径：已修复。循环每圈现在使用独立 `ChainLink` 克隆，避免前缀恢复写入 `wait` 时跨圈污染调度。
- 叶登记：无需改运行实现。旧 2× 报告是内部 `_analyze` 两次连续读取累计 profile 的测量错误；独立请求重置后两侧计数相同。
- 两张票均已标记 `Status: resolved`。

## 验收证据

| 检查 | 结果 |
|---|---|
| `tests/test_solver_cycle_restore_alias.gd` | PASS |
| `tests/test_solver_restore_schedule_scope.gd` | PASS |
| `tests/test_delay_prefix_restore.gd stage-a` | PASS；39 项全绿 |
| `tests/test_solver_checkpoint_trie.gd` | PASS；包括深层 checkpoint 变异检测 |
| `tests/test_solver_delay_dp.gd` | PASS；各样本结果/确定性/搜索形状全绿 |
| `tests/test_solver_index_equiv.gd` | PASS；全部 E 档与 cycle 等价 |
| 默认表独立叶登记测量 | 两侧指纹相同；330247 steps / 21 spatial / 7903 leaves |
| `python -m unittest tools.test_run_acceptance` | 29/29 OK |
| P6 spawn/pool 缓存与 Tier B 差分 | 继承 `.scratch/solver-p6-01/REPORT.md`，30/30 digest 全等、warm Tier B 全过 |

`tests/test_solver_routes_cycles_refactor.gd` 仍有两条旧性能断言失败（session_steps 不下降、prefix_restores=0）。这是交接记录的 compiled-scope 基线；本次修复不改变其契约，也未把尚未证明的跨 schedule 共享重新打开。其余该套测试通过，失败不会影响恢复结果逐字节等价。

## 变更

- `scripts/combat/combo_solver.gd`：循环证明每圈改用完整 `ChainLink` 克隆。
- `tests/test_solver_cycle_restore_alias.gd`：新增恢复别名回归。
- 本目录：复现、修正测量和验收证据。
