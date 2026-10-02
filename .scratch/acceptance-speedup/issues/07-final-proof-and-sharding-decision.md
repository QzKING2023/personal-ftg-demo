# 07: 全量终证与分片触发判定

Status: implemented(2026-10-02:冷扫全量 53.28min ≤1h,Tier B 终证 PASS,证据见 Comments)
Parent: [spec.md](../spec.md)
Blocked by: 04, 06(05 若实施则加)

## What to build

整个提速工程的收口:一次**冷跑**全量(默认配置:清扫开、全新缓存文件,mode=acceptance-sweep)证明墙钟 ≤1 小时,与 02 的串行基线做最终对拍。分片的触发判定已前置交付——2026-10-02 grilling 把分片由条件票转正为票据 08(全局前置清扫)并于本票之前实施,本票只记录饱和度与余量。这是全工程唯一一次"证明性"全量运行——此前的门都用定向 job。

## User stories covered

20, 21, 22(判定)。

## Acceptance criteria

- [x] 冷跑全量完成:默认配置(清扫开、全新缓存文件,mode=acceptance-sweep),墙钟 ≤1h;summary、状态文件、耗时归档到本票 scratch 验收目录。
- [x] 最终对拍:与 02 串行基线按 Tier B(ADR-0006 修订四)——`report_fingerprints` 集合(含 keys)、断言总数、各 job 结论逐项相等;不变量 `hits+misses==calls` 各 Solver job 成立、清扫热跑 misses 记录在案。
- [x] 饱和度与余量:清扫段各车道 busy 占比、三段墙钟分解、最长 job 耗时记录;给出未来连段边增长下保持 ≤1h 的余量推算(分片已由票据 08 前置交付,">20min 才触发"条款废止)。
- [x] 更新量级基线:新耗时结构写回 spec 的 Further Notes 或 Comments(供后续票据估计验收时长)。
- [x] 旧 PS runner 的去留决定:保留为历史基线或删除,记录理由(倾向保留至下一次全绿后再删)。

## Blocked by

- 04
- 06
- 08(2026-10-02 加入:分片前置交付)
- 05(若实施)

## Comments

### 终证结果(2026-10-02,工作树冻结于 2352684)

- **冷扫全量墙钟 3197.04s = 53.28min ≤ 1h**,15.7× 于 02 串行基线(50,149s)。
  三段分解:import 6.85s、枚举 45.37s(21 job 全 stub 枚举)、清扫 2566.0s、
  热跑 578.83s。发射 21:03:29 → runner.status `exit=0` 于 21:56:48(53min19s),
  22 行全绿(import 栅栏 + 20 test job + diagnose_inputs + main-smoke;
  mode=acceptance-sweep,19,342 断言,job 秒和 1,374s)。
- **Tier B 终证 PASS**:与 02 串行基线按名对齐,20/21 job 全字段相等(含
  report_fingerprints 与 keys 请求序);test_move_table 按 06 先例走包含
  (基线 6 fps/6 key-groups ⊆ 冷扫 8/8,差异仅 analyze-manifest 调用可见性);
  test_delay_prefix_restore 为 04 新增 job(34 断言,自身 harness 门禁)。
  断言总数 +85 全部归属已门禁变更(solver_cache +47、move_table +4、
  delay_prefix_restore +34),无未解释漂移。不变量 hits+misses==calls 各
  Solver job 由 compare_summaries(tier-b, right)校验通过。
- **枚举缺口实形复现并自愈**:全新缓存下 sweep.gaps=2 descriptor
  (0a3297e3…、fa7ff991…,stub worker <1s exit=1)→ 热跑 miss 5 次
  (hit_profiles 2、move_table 2、replay_acceptance 1)就地现算,墙钟贡献
  ≈ 最长两 job 并行(replay 576s / hit 544s);Tier B 仍全等,正确性无损。
  与 08 gate-3 预言一致:每次全新缓存的冷跑都会重付这笔一次性缺口成本。
- **饱和度**:lane_busy_ratio **0.8736**(busy 17,934s / wall 2,566s / 8 车道,
  有效吞吐 ≈6.99 任务秒/秒)——08 子集实测 0.338 系尾部主导,全量 62 任务
  平坦清单结构性饱和的预言兑现。任务分布:max 1138s、p90 660s、median 304s。
- **余量推算**:预算余量 403s → 折合清扫 busy ≈ +2,820s(+15.7%),按当前重任务
  体量(600~1,140s/个)≈ 可再吸收 2~4 个重型唯一请求;枚举段随边增长近常数,
  热跑缺口每新增一个 ≈ +550~600s 墙钟。触顶第一手段(零工程量):并发 8→16
  (24 逻辑核,清扫吞吐近似翻倍;默认 8 为日常开发留核)。

### 量级基线(供后续票据估时,亦同步至 spec Further Notes)

- 全量冷跑(每次全新缓存):**~53min**。全量迭代重跑(热缓存):预期 6~10min
  (枚举 45s + 清扫全命中 + warm,缺口自愈成本只在首跑)。
- 定向票据验证(触及测试):≈ 单 job 热跑时长(combo 32s / spatial 53s /
  restore 63s 量级),分钟级。
- 单一重型唯一请求现算成本:~300-1,140s(清扫段口径,已含 04 前缀恢复红利)。

### 决定:PS runner 去留

保留 `run_acceptance.ps1` 至下一次全绿周期后再议删除:它是 02 之前全部差分门
的同构基线生成器与契约参照,删除不影响日常(编排器已为默认路径);待下一个
迭代周期确认无人再需要 PS 基线再删,避免证明链断档。

### 证据目录(`.scratch/acceptance-speedup/final-07/`)

- `launch-cold-full.sh` + `launch.log` + `full.pid`:发射脚本(强制校验缓存
  文件发射前不存在)与时刻留档。
- `full/`:summary.json(mode=acceptance-sweep)、runner.status.txt=exit=0、
  sweep.json(三段墙钟/62 任务行/饱和度/缺口/warm misses)、全部 job 日志。
- `monitor.log`:5 分钟粒度进度线(清扫段 62 任务 ~45min 走完)。
- `EVIDENCE.md`:全部 AC 的完整归档(含对拍排除集与推算模型)。
- `tierb-final.out`(20 job 全字段相等)+ `tierb-baseline-subset.json` /
  `tierb-cold-subset.json`(按名对齐产物,`tierb_build.py` 生成)+
  `tierb-move-table.out` / `tierb-move-table-keys.out`(包含检查)。
- `solver-results.cache`:本次冷跑的最终缓存(60 条 canonical,含全部唯一
  请求;下次全量对它为热跑)。
