# 06: 跨进程结果缓存与 fragment 合并

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 02

## What to build

把 ComboSolver 现有的请求级完整结果缓存(entries:descriptor + 报告快照)持久化到机器本地文件:job 启动时只读加载规范缓存,运行中新条目写各自的 per-job fragment,编排器在 run 收尾把 fragments 合并回规范文件——无锁、并发安全。命中校验沿用现有 descriptor 规范文本全等(不只比摘要);失效沿用现有语义签名(战斗脚本逐文件哈希、表内容摘要、引擎版本、限额常量)——这些防过期机制都是现成的,本票只做持久化与合并。

先查一个异常:`test_combo_solver` 此前 27 个请求零缓存计数(0 hit/0 miss/0 bypass,其他 job 都有计数)——查明是按设计禁用还是统计被重置;若禁用,决定并记录持久化是否覆盖它(它是并行墙钟的下界,值得覆盖)。

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
