# 验收提速只走机械等价变换，语义削减永久出局

状态：accepted（2026-09-30 设计决定，尚未实现）

全量验收耗时随 Solver 路线膨胀从 2h（票据 06）涨到 5.6h（票据 07）、当前规模约 10–15h。最便宜的提速杠杆是削减搜索本身（减少延迟候选、循环圈数、观测帧数、空间档位），被明确拒绝：验收的证明力来自搜索的完整性，砍搜索等于用更弱的证明换速度。获批的路线只有三类机械等价变换——runner 并行化（Python 编排器，并发 8）、`_delay_dfs` 等重放点的前缀快照/恢复（复用已过差分证明的 CombatSession seam）、以及请求级结果缓存的跨进程持久化——每类独立过差分门：统一以 acceptance report fingerprint 为等价 oracle（并行对串行 summary.json 除 `seconds` 外逐字段相等；缓存冷/热两跑 fingerprint 集合相等；Solver 内部改动另加逐叶子完整 run dict 比较），搜索语义（字典序枚举、budget 按叶子计数、proof_mode 逐圈快照、首条成立即返回、失败排序）全部冻结。目标：全量冷跑 ≤1h；若做完后最长 job 仍 >20min，才追加 job 内请求分片票冲击 ≤30min。

曾考虑并否决：语义削减（上述）；标签级结果复用（曾因不完整键与共享可变报告被回滚，获批形态是带 descriptor 全等校验的完整请求缓存）。

修订（2026-09-30，票据 01 落地时）：差分 oracle 的排除字段从 `seconds` 扩为 `seconds`/`total_seconds`/`solver_elapsed_ms` 三个——三者同为墙钟测量，同一 runner 两次运行也不相等，不扩则门自身不稳定；计数与 fingerprint 等全部其余字段仍逐字段相等。

修订（2026-09-30，票据 03 落地时）：Solver 耗时分解插桩常开并透传进 summary（`solver_profile` 的 `total_ms`/`delay_leaf_ms`/`edge_probe_ms`/`gap_enum_ms`/`route_walk_ms`/`other_ms`），六个键与 `seconds` 同为墙钟测量，进同一排除集；其 `*_runs` 计数是确定性搜索形状量，保持逐字段相等。插桩本身零语义影响（只读墙钟、不改任何搜索行为与报告内容），归类为机械等价纪律下的观测手段而非提速变换。

修订（2026-10-02，grilling 定案）：**job 内请求分片由条件票转正为第四类机械等价变换**（全局前置清扫，票据 08），废止本 ADR 正文"若做完后最长 job 仍 >20min，才追加 job 内请求分片票冲击 ≤30 分钟"的条件条款。转正依据：用户要求 8 核饱和，且 ≤1h 目标须为未来连段边增长保留余量（性能尽量高，而非"恰好达标"）。清扫 = 枚举（编排器专用 stub 模式：miss 记 descriptor、返回拒绝形态报告、不计算）→ 唯一请求跨 job 去重后铺满并发车道算完写缓存 fragment（复用票据 06 基建）→ 全部 job 热缓存正常跑；对搜索语义零触碰。

同修订确立**差分 oracle 两级制**（自缓存去重/热跑/清扫起，全字段相等不再可能——缓存计数与 profile 计数"因设计而异"，它们是性能遥测而非语义载体）：

- **Tier A（同模式对拍）**：冷对冷（并行对串行、插桩前后、前缀恢复前后）——compare_summaries 全字段相等，排除集仅修订一/三累计的计时测量字段；`*_runs` 计数与 `combo_cache` 必须相等。
- **Tier B（跨模式对拍）**：去重/热跑/清扫跑 vs 冷串行基线——在全字段相等上追加排除 `combo_cache`/`solver_profile`/`mode`（及 `appdata`，票据 02 既有）；语义载体全数保留：各 job 退出码、script_errors、断言数、pass_lines、`solver_calls`、`report_fingerprints`（指纹+次数+keys 请求序键）逐字段相等。另加不变量：各 Solver job `hits+misses==calls`；清扫热跑 misses==0 为通过形态（>0 如实记录为枚举缺口/性能债，不判死）；枚举双跑 descriptor 序列确定。
- 分级原则：Tier B 不是放松——移出比对的字段由不变量接管，而非置之不理；凡比较双方运行模式相同，必须用 Tier A。

修订五（2026-10-02，票据 06 实现时）：两处落地口径澄清，不动两级制本身。①不变量的完整账面形式为 `hits+misses+bypasses==calls`——refused/不可键请求（非法选项、manifest 加载失败、拒绝形态）自本票起计 bypass（此前这类请求全然不计，修订四的字面形式 `hits+misses==calls` 在含拒绝请求的 job 上对 02 基线即不成立，如 test_smoke 的坏 manifest 分析）；`bypasses==0` 的 job 上两者同式，0/0/0 型零计数异常在完整账面下依然必被抓获。②对**跨树基线**（冻结的 02 串行基线 vs 后续票种的树）做 Tier B 时，若票种自身新增了测试断言，`pass_lines`/`assertions`/`total_assertions` 追加排除并记录增量——语义载体以 `report_fingerprints`（含 keys）与退出码/script_errors 为准；同树对拍（如冷对热）仍逐字段含断言数。
