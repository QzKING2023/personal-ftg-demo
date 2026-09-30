# 验收提速只走机械等价变换，语义削减永久出局

状态：accepted（2026-09-30 设计决定，尚未实现）

全量验收耗时随 Solver 路线膨胀从 2h（票据 06）涨到 5.6h（票据 07）、当前规模约 10–15h。最便宜的提速杠杆是削减搜索本身（减少延迟候选、循环圈数、观测帧数、空间档位），被明确拒绝：验收的证明力来自搜索的完整性，砍搜索等于用更弱的证明换速度。获批的路线只有三类机械等价变换——runner 并行化（Python 编排器，并发 8）、`_delay_dfs` 等重放点的前缀快照/恢复（复用已过差分证明的 CombatSession seam）、以及请求级结果缓存的跨进程持久化——每类独立过差分门：统一以 acceptance report fingerprint 为等价 oracle（并行对串行 summary.json 除 `seconds` 外逐字段相等；缓存冷/热两跑 fingerprint 集合相等；Solver 内部改动另加逐叶子完整 run dict 比较），搜索语义（字典序枚举、budget 按叶子计数、proof_mode 逐圈快照、首条成立即返回、失败排序）全部冻结。目标：全量冷跑 ≤1h；若做完后最长 job 仍 >20min，才追加 job 内请求分片票冲击 ≤30min。

曾考虑并否决：语义削减（上述）；标签级结果复用（曾因不完整键与共享可变报告被回滚，获批形态是带 descriptor 全等校验的完整请求缓存）。

修订（2026-09-30，票据 01 落地时）：差分 oracle 的排除字段从 `seconds` 扩为 `seconds`/`total_seconds`/`solver_elapsed_ms` 三个——三者同为墙钟测量，同一 runner 两次运行也不相等，不扩则门自身不稳定；计数与 fingerprint 等全部其余字段仍逐字段相等。
