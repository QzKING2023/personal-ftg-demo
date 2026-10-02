# 06: 跨进程结果缓存与 fragment 合并

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 02

## What to build

把 ComboSolver 现有的请求级完整结果缓存(entries:descriptor + 报告快照)持久化到机器本地文件:job 启动时只读加载规范缓存,运行中新条目写各自的 per-job fragment,编排器在 run 收尾把 fragments 合并回规范文件——无锁、并发安全。命中校验沿用现有 descriptor 规范文本全等(不只比摘要);失效沿用现有语义签名(战斗脚本逐文件哈希、表内容摘要、引擎版本、限额常量)——这些防过期机制都是现成的,本票只做持久化与合并。

先查一个异常:`test_combo_solver` 此前 27 个请求零缓存计数(0 hit/0 miss/0 bypass,其他 job 都有计数)——**根因已于 2026-10-02 grilling 定位**(见 Comments):结果缓存只在 `solve()` 里查询/写入(combo_solver.gd:647-695),`analyze()`(:479)与 `analyze_manifest()`(:469)完全不接缓存(不查、不写、连 bypass 都不计)。本票修复 = 给 analyze 入口建同型 descriptor(`entrypoint: "analyze"`,单面向)接进同一查/存路径——`solve()` 机制已过差分证明,纯复用;`test_move_table` 同症一并覆盖。

## User stories covered

14, 15, 16, 17, 18, 19, 26。

## Acceptance criteria

- [ ] 零缓存计数异常查明并记录结论;若 test_combo_solver 按设计禁用缓存,给出保留或放开的决定及理由。
- [ ] 缓存文件位于仓库本地 gitignore 目录;验收默认开启;`--acceptance-no-reuse` 基线模式保留且行为不变(不加载不写入)。
- [ ] fragment 合并:并行 job 各写各的 fragment,收尾合并幂等(两 job 产出相同条目时合并结果正确)、无锁。
- [ ] 失效行为验证:改动任一战斗脚本或表资源后,旧条目不再命中(语义签名口径);引擎版本变化同理。
- [ ] 冷/热门:同表第二次全量(或覆盖全部唯一请求的定向子集)与冷跑的 fingerprint 集合、断言计数逐项相等。
- [ ] 收益记录:热跑(第二遍)相对冷跑的耗时对比;若命中率远低于 98 请求中 30 唯一的理论上界,解释差异。

## Blocked by

- 02

## Comments

### 根因定位与经济账(2026-10-02 grilling)

- **根因**:结果缓存只在 `solve()` 里被查询/写入(combo_solver.gd:647-695);`analyze()`(:479)与 `analyze_manifest()`(:469)直接 `ComboSolver.new(table)._analyze()`,不碰缓存。走 analyze 入口的 job(test_combo_solver、test_move_table)因此 0/0/0;走 solve 入口的 job(route/cycles/spatial/entry/replay/hit)正常计数——同一 metrics 层、两种入口,坐实根因。
- **经济账(02 基线日志实测,含争用膨胀,比例为准)**:test_combo_solver 27 请求仅 11 唯一——fp 50b5b845 重算 16 次(单次 ~655s,合计 ≈10,490s,占该 job 63%)、fp 799250dd 重算 2 次;修复后 16,637s→~5,625s(job 内去重 2.7x)。test_move_table 同症(6 请求 0.86M 叶次全重算)。
- **门口径**:本票去重修复与冷/热门均走 Tier B(ADR-0006 修订四)——全字段相等追加排除 `combo_cache`/`solver_profile`/`mode`(及 `appdata`),不变量 `hits+misses==calls`;`report_fingerprints` 含 keys 逐字段相等(热跑不改变请求顺序,keys 序列保持)。
- **用户裁定(2026-10-02)**:修复留在本票 AC#1 内做、不拆票提前(选项 A);04 先行,本票殿后。注意:修复后冷跑并行墙钟 = cycles 的 ~9,607s ≈ 2.7h,仍离 ≤1h 甚远——04 的必要性不被本票吸收。
