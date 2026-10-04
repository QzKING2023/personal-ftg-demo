# P3 默认表循环恢复等价性

Status: resolved
Labels: ready-for-human

## 问题

P3 的前缀 trie 只使用输入内容作为节点路径。不同延迟调度可能共享输入前缀，但预期命中帧不同；恢复后复用的 `verified`、快照和终止状态会改变默认表循环的最远失败归属。

## 修复

`ComboSolver._memo_scope_key` 现在追加编译调度语义签名：预期命中帧、预期招式、jump/landing 锚点和尾部模式。所有运行路径和前缀捕获路径均使用带调度签名的 scope，避免跨调度 graft。

## 验证

- `tests/test_solver_restore_schedule_scope.gd`：确认相同输入前缀但不同预期命中调度得到不同 scope。
- `tests/test_solver_checkpoint_trie.gd`：25/0，现有 checkpoint 恢复差分门全绿。
- `tests/test_solver_cycle_invariant.gd`：29/0，循环证明回归全绿。

## Comments

2026-10-04：P5 记录的默认表 fingerprint 漂移追查到该 scope 缺口；修复已直接落地，问题归档。
