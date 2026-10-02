# Ticket 07 最终证明归档(2026-10-02)

全工程唯一一次证明性全量运行。工作树冻结于 2352684(08 交付后)。

## AC#1 冷跑全量 ≤1h — PASS

- 发射:`launch-cold-full.sh`,`launch.log` = `2026-10-02 21:03:29`,pid 332。
- 配置:默认编排器(引擎默认路径、并发 8)、`--sweep`、全新缓存文件
  `final-07/solver-results.cache`(发射前不存在,由 launch 脚本强制校验)。
- 结束:`full/runner.status.txt` = `exit=0`,21:56:48(mtime)。
- **墙钟 = 发射到状态落盘 53min19s(stage_walls.total 3197.04s = 53.28min)≤ 1h**;
  22/22 行全部 exit=0、script_errors=0(import 栅栏 + 20 个 test job +
  diagnose_inputs + main-smoke;枚举段覆盖栅栏外 21 个 job)。
- `summary.mode == "acceptance-sweep"`,22 tests,19,342 assertions,job 秒和 1,374s。

## AC#2 最终对拍(Tier B,ADR-0006 修订四)— PASS

产物:`tierb-final.out`、`tierb-baseline-subset.json`、`tierb-cold-subset.json`、
`tierb-move-table.out`、`tierb-move-table-keys.out`(对齐脚本 `tierb_build.py`)。

- 与 02 串行基线(baseline-02/serial-full/summary.json,mode=acceptance-reuse,
  19,257 断言,job 秒和 50,149s)按名对齐比较。
- **20/21 基线 job 全字段相等**:compare_summaries `--tier-b --invariant-side right
  --exclude pass_lines assertions total_assertions` exit=0 —— 含
  report_fingerprints(集合与序)、solver_report_keys(含 keys 请求序)、
  solver_calls/underlying、exit/script_errors、pass_lines 之外的结论字段。
- **test_move_table 按 06 先例以包含为 oracle**:基线 6 fps ⊆ 冷扫 8 fps、
  基线 6 key-groups ⊆ 冷扫 8(analyze_manifest 缓存入口化后调用可见性扩大,
  06 门禁 gate-06.sh 同款处理)。差异仅 +3 calls(analyze-manifest-7/8/9)。
- **test_delay_prefix_restore(04 新增 job)不在基线中**:由 04 自身差分 harness
  门禁,此处 34 断言全过。
- 断言总数 19,257 → 19,342(+85)全部归属已门禁变更:solver_cache +47、
  move_table +4(06)、delay_prefix_restore +34(04)。无未解释漂移。
- **不变量**:各 Solver job `hits+misses+bypasses == solver_calls` 由
  compare_summaries(tier-b, right)校验通过。
- **清扫热跑 misses 记录在案**:warm.misses_total=5 —— hit_profiles 2、
  move_table 2、replay_acceptance 1(hits 2/6/2)。枚举缺口 2 个 descriptor
  (sweep.gaps = 0a3297e3…、fa7ff991…;对应 worker stub 形态 exit=1 于 <1s,
  属守卫依赖请求,stub 无法重建)——热跑就地重算自愈,正确性以 Tier B 为
  oracle,性能债留档。

## AC#3 饱和度、三段分解、最长任务、余量

三段墙钟(full/sweep.json stage_walls):

| 段 | 墙钟 |
|---|---|
| import | 6.85s |
| enumerate(21 job stub 全枚举) | 45.37s |
| sweep(62 唯一任务 × 8 车道) | 2566.0s |
| warm(全 job 热跑) | 578.83s |
| **total** | **3197.04s(53.28 min)** |

- 清扫段车道饱和:**lane_busy_ratio = 0.8736**(busy 17,934s / wall 2,566s / 8
  车道 → 有效吞吐 ≈6.99 任务秒/秒)。
- 任务分布(62):max 1138s、p90 660s、median 304s;重尾集中(combo 类)。
- 最长清扫任务 1138s + 1132s(86bd4a5b…、809584f5…)。
- 最长热跑 job:test_replay_acceptance 576.05s 与 test_hit_profiles 544.10s
  并行(即 2 个枚举缺口请求的就地重算),其余热 job ≤63s。

### 余量推算(连段边增长下保持 ≤1h)

- 模型:`wall ≈ 7s + 45s + Σbusy/(8×0.874) + warm`;当前 Σbusy=17,934s。
- 现有预算余量 3600−3197=403s → 折合清扫 busy 余量 ≈ 403×6.99 ≈ **2,820s
  (+15.7%)**;按当前重任务体量(600~1,140s/个)≈ **可再吸收 2~4 个重型唯一
  请求**。
- 枚举段随边增长近常数(只随 job 数走,45s/21 job);热跑段除缺口自愈外
  ≤63s/job 且 8 车道并行,缺口请求每新增一个 ≈ +550~600s 墙钟(当前形态)。
- 触顶前的第一手段(零工程量):并发 8→16(24 逻辑核,清扫吞吐近似翻倍;
  默认 8 为日常开发留核,冲刺时可调 `--concurrency`)。

## 量级基线(供后续票据估时)

- 02 串行基线:50,149s(13.93h)。07 冷扫全量:**3197s(53.3min),15.7×**。
- 迭代重跑(热缓存)预期:枚举 45s + 全命中清扫 0 + warm ≈ 6~10min。
- 定向票据验证(触及测试时):≈ 单 job 热跑时长,分钟级。

## PS runner 去留

保留 `run_acceptance.ps1` 至下一次全绿周期后再议删除:它是 02 之前全部差分门
的同构基线生成器,删除不影响日常(编排器为默认);等下一个迭代周期确认无人
再需要 PS 基线再删,避免证明链断档。
