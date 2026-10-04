# 恢复路径等价性

Status: resolved
Labels: ready-for-agent

默认表空中循环在恢复开关两侧报告断链原因不同。定位并修复，保留搜索顺序、完整性与失败排序；最小回归和默认表全语义对拍必须通过。

## Comments

2026-10-04：从交接接手，旧 compiled scope 修复不是本症状的充分修复。

## Answer

根因是 `_simulate_cycle` 将同一组 `ChainLink` 引用重复追加到每一圈；前缀恢复会原地写入 `wait`，后续圈因此污染前一圈的编译调度。现在每圈使用完整字段克隆，恢复开关两侧的代表性循环结果逐字节相等。回归：`tests/test_solver_cycle_restore_alias.gd` 通过；既有 `tests/test_delay_prefix_restore.gd` 通过（39 项）；恢复 scope 回归通过。
