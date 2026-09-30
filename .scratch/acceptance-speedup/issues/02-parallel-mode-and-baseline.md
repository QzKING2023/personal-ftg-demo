# 02: 并行模式与串行全量基线

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 01

## What to build

在 01 的编排器上加并发:import job 先单独完成(共享导入缓存目录的写保护栅栏),测试 job 以默认并发 8 扇出,每个 job 保持 01 的隔离口径。本票同时交付**唯一的全量串行基线**:Python 串行全量过夜跑一次并归档,此后所有差分门(并行、`_delay_dfs`、缓存、终证)都对着它比,不再跑第二遍串行全量。

## User stories covered

1, 2, 6, 7。

## Acceptance criteria

- [ ] import 先行栅栏:import job 退出后测试 job 才启动;测试 job 对共享目录只读的假设用"两个并发实例实跑一次"经验验证(结果记录在 Comments)。
- [ ] 并发默认 8、`--concurrency` 可调;等待池满员补位,不按完成序写 summary(保持规范 job 序)。
- [ ] 串行全量基线:一次后台过夜运行完成,summary、状态文件、总耗时归档到本票的 scratch 验收目录。
- [ ] 并行差分门:并行全量 vs 串行基线,summary 除 `seconds` 外逐字段相等(含各 job 的 solver metrics、fingerprint 集合、退出码、script_errors)。
- [ ] 记录并行墙钟与最长 job 耗时(预期墙钟 ≈ 最长 job + 栅栏时间);若与预期量级不符,先解释再收票。
- [ ] 操作注意写进 Comments:并行期间不得按进程名批量杀 Godot(会误杀并行实例);开发与验收并行时留意核数与共享目录。

## Blocked by

- 01
