# 06: 跨进程结果缓存与 fragment 合并

Status: implemented
Parent: [spec.md](../spec.md)
Blocked by: 02

## What to build

把 ComboSolver 现有的请求级完整结果缓存(entries:descriptor + 报告快照)持久化到机器本地文件:job 启动时只读加载规范缓存,运行中新条目写各自的 per-job fragment,编排器在 run 收尾把 fragments 合并回规范文件——无锁、并发安全。命中校验沿用现有 descriptor 规范文本全等(不只比摘要);失效沿用现有语义签名(战斗脚本逐文件哈希、表内容摘要、引擎版本、限额常量)——这些防过期机制都是现成的,本票只做持久化与合并。

先查一个异常:`test_combo_solver` 此前 27 个请求零缓存计数(0 hit/0 miss/0 bypass,其他 job 都有计数)——**根因已于 2026-10-02 grilling 定位**(见 Comments):结果缓存只在 `solve()` 里查询/写入(combo_solver.gd:647-695),`analyze()`(:479)与 `analyze_manifest()`(:469)完全不接缓存(不查、不写、连 bypass 都不计)。本票修复 = 给 analyze 入口建同型 descriptor(`entrypoint: "analyze"`,单面向)接进同一查/存路径——`solve()` 机制已过差分证明,纯复用;`test_move_table` 同症一并覆盖。

## User stories covered

14, 15, 16, 17, 18, 19, 26。

## Acceptance criteria

- [x] 零缓存计数异常查明并记录结论;若 test_combo_solver 按设计禁用缓存,给出保留或放开的决定及理由。(根因 = analyze 系入口不接缓存,见 Comments;非禁用,本票接入)
- [x] 缓存文件位于仓库本地 gitignore 目录;验收默认开启;`--acceptance-no-reuse` 基线模式保留且行为不变(不加载不写入)。(默认 `.cache/acceptance/solver-results.cache`,`.cache/` 已 gitignore;`--no-reuse` 不注入环境变量且跳过合并,Godot 侧双保险解析 `--acceptance-no-reuse`)
- [x] fragment 合并:并行 job 各写各的 fragment,收尾合并幂等(两 job 产出相同条目时合并结果正确)、无锁。(tools/test_run_acceptance.py::CachePlumbingTests;canonical 优先 + fragment 名字序的固定合并序,重复合并字节不变)
- [x] 失效行为验证:改动任一战斗脚本或表资源后,旧条目不再命中(语义签名口径);引擎版本变化同理。(gate D:combat_session.gd 追加一行注释即未命中;表资源 = test_move_table 编辑 base_damage 后未命中;引擎版本经 descriptor 的 Engine.get_version_info() 字段承载——机制与 solve() 自票据 02 起同源,测试侧无法换引擎实测,留档说明)
- [x] 冷/热门:同表第二次全量(或覆盖全部唯一请求的定向子集)与冷跑的 fingerprint 集合、断言计数逐项相等。(gate A:10 个 Solver job 子集冷/热 `--tier-b` 全过——含 fingerprint、keys、断言计数;gate B:12 个未改测试 job 对 02 串行基线逐字段相等)
- [x] 收益记录:热跑(第二遍)相对冷跑的耗时对比;若命中率远低于 98 请求中 30 唯一的理论上界,解释差异。(子集串行基线 49,001s → 冷 22,562s → 热 178s;热跑全部可缓存请求命中、misses=0——上界达成)

## Blocked by

- 02

## Comments

### 根因定位与经济账(2026-10-02 grilling)

- **根因**:结果缓存只在 `solve()` 里被查询/写入(combo_solver.gd:647-695);`analyze()`(:479)与 `analyze_manifest()`(:469)直接 `ComboSolver.new(table)._analyze()`,不碰缓存。走 analyze 入口的 job(test_combo_solver、test_move_table)因此 0/0/0;走 solve 入口的 job(route/cycles/spatial/entry/replay/hit)正常计数——同一 metrics 层、两种入口,坐实根因。
- **经济账(02 基线日志实测,含争用膨胀,比例为准)**:test_combo_solver 27 请求仅 11 唯一——fp 50b5b845 重算 16 次(单次 ~655s,合计 ≈10,490s,占该 job 63%)、fp 799250dd 重算 2 次;修复后 16,637s→~5,625s(job 内去重 2.7x)。test_move_table 同症(6 请求 0.86M 叶次全重算)。
- **门口径**:本票去重修复与冷/热门均走 Tier B(ADR-0006 修订四)——全字段相等追加排除 `combo_cache`/`solver_profile`/`mode`(及 `appdata`),不变量 `hits+misses==calls`;`report_fingerprints` 含 keys 逐字段相等(热跑不改变请求顺序,keys 序列保持)。
- **用户裁定(2026-10-02)**:修复留在本票 AC#1 内做、不拆票提前(选项 A);04 先行,本票殿后。注意:修复后冷跑并行墙钟 = cycles 的 ~9,607s ≈ 2.7h,仍离 ≤1h 甚远——04 的必要性不被本票吸收。

## 实现记录(2026-10-02 交付)

### 交付物

- `scripts/combat/combo_solver.gd`:①`analyze()`/`analyze_manifest()` 接入与 solve() 同一查/存路径(抽出 `_cache_query`/`_cache_store`/`_count_cache_bypass` 三入口共用的统一路径;命中校验仍为 descriptor 规范文本全等);②`_build_analyze_request` 生成 `entrypoint="analyze"/"analyze_manifest"` 同型 descriptor,维度与 solve 逐字段一致(表内容、manifest 文件签名、引擎版本、语义签名、限额常量),入口名单独成键防两入口互命中;③持久化层:启动按 `FTG_SOLVER_RESULT_CACHE` 只读加载规范缓存(header 版本不符整文件拒载)、新条目按 `FTG_SOLVER_RESULT_CACHE_FRAGMENT` 写 per-job fragment(每次存储整文件重写,坏行在加载/合并侧跳过);④refused/不可键请求计 bypass——账面完整化:`hits+misses+bypasses==calls`(修订四字面形式 `hits+misses==calls` 在含拒绝请求的 job 上对 02 基线即不成立:smoke 1 调用 0/0/0、entry 19 调用 17 账面;bypasses==0 时两式同式,0/0/0 异常仍必被抓获,见 ADR 修订五①)。
- `tools/run_acceptance.py`:`--cache` 转正(默认 `.cache/acceptance/solver-results.cache`,gitignore);job 环境注入两个缓存变量(**fragment 父目录必须预建**——Godot FileAccess 不能建目录,首版冷跑因此全无 fragment,已修并有单测);收尾 `merge_cache_fragments` 无锁合并(canonical 优先 + fragment 名字序,幂等字节不变,坏行计数跳过)产出 `cache-merge.json`;summary 行新增 `solver_report_keys`(fingerprint→keys 映射,门 A/B 逐字段比较)。
- `tools/compare_summaries.py`:`--tier-b`(追加排除 combo_cache/solver_profile/mode/appdata + 账面不变量)与 `--invariant-side`(对冻结基线比较时不变量只约束现役侧)。
- `docs/adr/0006`:修订五(①账面完整形式;②跨树基线比较时票种自身新增断言/请求的排除与包含检查口径)。
- 测试:`tests/test_solver_cache.gd` +9 用例(analyze 计数/隔离/互不碰撞、拒绝形态 bypass、fragment 写盘形态与重载往返、descriptor 篡改不命中、no-reuse 不写、禁用不写);`tests/test_move_table.gd` +1 用例(manifest 命中/文件编辑失效,**模式无关断言**——热跑首调命中持久化条目同样成立);`tools/test_run_acceptance.py` CachePlumbingTests;`tools/test_compare_summaries.py`(新文件,不进 Godot job 集)。

### 关键实现决定与教训

- **持久化编码 = JSON 行(外)+ var_to_str(内)**:探针实测 Godot 4.5 的 `JSON.parse_string` 把 int 解析成 float(类型保真破坏),`var_to_str`/`str_to_var` 逐字段全等——JSON 行保证 Python 编排器可原生合并,var_to_str 内嵌保证类型保真。条目行 `{"digest":..., "entry":"<var_to_str>"}`,首行 header `{"schema":"ftg-demo-solver-result-cache","version":1}`。
- **三处中途返工(不变量/门立了就抓到)**:①我在 test_move_table 的测试里调 `clear_result_cache()` 抹掉同 job 早前请求账面 → Tier B 不变量当场抓获(9 调用只账面 3),改为计数差值断言;②该测试首版按冷语义写死"首调必未命中",热跑首调命中持久化条目(设计行为!)而失败,改为模式无关断言(同请求必命中不重算、文件编辑后绝不返回旧条目报告);③fragment 父目录未预建导致首版冷跑零 fragment。热侧以 run/hot2 重跑(修复为纯断言改动:4 条检查数不变、零生产代码变化、fingerprint 不变),已在 gate 脚本头注记。
- **引擎版本失效**无独立测试(无法在测试内换引擎);其承载机制(descriptor 内 `Engine.get_version_info()` 全字段)与 solve() 自票据 02 起同源,analyze descriptor 现含同一维度。

### Gate 证据(`.scratch/acceptance-speedup/cache-06/gate/`,gate-06.sh 可复跑)

- **gate A(冷对热,Tier B)PASS**:10 个 Solver job 子集(覆盖全部唯一请求)冷跑(全新缓存文件)vs 热跑(同一 canonical)逐字段相等——fingerprint 集合、solver_report_keys、断言计数、退出码;两侧账面不变量全过。
- **gate B(冷对 02 串行基线,Tier B)PASS**:12 个本票未改测试的 job 逐字段相等(`--invariant-side right`:基线侧的 0/0/0 与缺 bypass 正是本票修复对象);test_move_table(本票 +3 请求)以指纹包含检查单独覆盖:基线 6 fps ⊆ 冷跑 8 fps(gate-b-containment.out)。
- **gate C(持久化往返)PASS**:探针自存 → Python 合并进 canonical(58→59 条)→ 全新进程命中。
- **gate D(语义失效)PASS**:combat_session.gd 追加一行注释,同请求立即未命中。
- 单测:Godot test_solver_cache(42 PASS)、test_move_table(冷/热两模式均过);Python 18 tests OK;轻量 job 全量回归 8/8(test_air_d_landing…test_launcher_air_exits 全 exit 0)。

### 收益(02 基线 → 本票后,同子集)

| 指标 | 02 串行基线 | 冷跑(并行8,含 04 提速) | 热跑(同 canonical 二跑) |
|---|---|---|---|
| 子集总耗时(串行和) | 49,001s | 22,562s | **178s(275x)** |
| test_combo_solver | 16,637s(27 请求 0/0/0) | 3,408s(16 hit/11 miss) | **32s(27/27 命中)** |
| 热跑未命中 | — | 48 misses(各 job 唯一请求) | **0** |

- 命中率 = 可缓存请求的 100%:热跑每 job misses=0、bypasses 仅来自拒绝形态(smoke 1、entry 2、spatial 2、move_table 1)——**98 请求 30 唯一的理论上界达成**,无需解释缺口。与 02 结构对账:基线的 combo 27 请求 11 唯一(fp 50b5b845 重算 16 次)在冷跑内去重为 16 hit/11 miss,与 grilling 预估(~5,625s 量级)一致量级(实测 3,408s,含 04 提速叠加);跨 job/跨 run 重复由持久化吸收(热跑全命中)。
- 对后续票的意义:迭代重跑(改测试/非战斗代码)在该机器上趋近 178s 子集量级;票据 08 清扫复用 fragment 基建。
