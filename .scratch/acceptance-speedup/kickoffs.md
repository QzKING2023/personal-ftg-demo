# 验收提速:各阶段启动提示词

用法:每张票开一个**全新会话**(清空上下文),粘贴对应阶段的提示词代码块。提示词已内嵌全部必要约束,不需要额外交代。

编写原则(按 agent brief 规范):票据文件是权威规格——验收标准、范围边界都在票里,提示词只做三件事:指明读什么、钉住会话级过程约束(票据写不了的部分)、定义完成协议。不在提示词里复述票据内容,避免两处真相。

通用红线(每条提示词均引用,此处供人查阅):

- **语义冻结(ADR-0006)**:字典序枚举、budget 按叶子计数、proof_mode 逐圈快照、首条成立即返回、失败代表性排序,一行不动;语义削减(候选/圈数/帧数/档位)禁止。
- **等价 oracle 两级制(ADR-0006 修订四,2026-10-02)**:同模式对拍(冷对冷)全字段相等;跨模式(去重/热跑/清扫 vs 冷串行基线)走 Tier B——追加排除 combo_cache/solver_profile/mode/appdata,另加不变量。票据已写明适用级别,拿不准先查 ADR。
- **验证经济学**:票据级验证只跑定向 test job + 差分 harness;全量只在 02(串行基线)和 07(终证)各跑一次。
- **长任务**:一律后台运行,退出码落盘,以输出文件行数判活;不以进程名批量杀 Godot(会误杀并行实例)。
- **开工协议**:先看 git 状态;若工作树有他票在途改动,停下来与用户确认。
- **完成协议**:票据验收项全部勾选、`Status:` 改为 `implemented`、Comments 记录证据路径与关键数据;按 /implement 流程自审后提交到当前分支。

---

## 01 Python 编排器——串行模式与输出契约对等(无阻塞)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/01-python-orchestrator-serial.md

会话约束:
- 只做串行模式;并发扇出属于票据 02,不要顺手实现。
- 旧 PowerShell runner 保留不删——它是差分基线与回退路径。
- 验收用快 job 子集对拍(覆盖全部输出形态),不跑全量。
- 长后台任务按验收运行约定:退出码落盘、输出文件行数判活。
```

## 03 Solver 耗时 profile 插桩(无阻塞,可与 01 并行)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/03-solver-time-profile.md

会话约束:
- 只加插桩,零语义影响;先跑定向 test job 确认 fingerprint 与断言计数不变,再交付。
- 分类口径(哪些调用点计入哪类)先写进票据 Comments 再动手实现。
- 插桩常开,不是调试开关——后续票据的前后对比依赖统一口径。
- 产出的 profile 报告归档到本票 scratch 目录,票据 04/05 要引用它。
```

## 02 并行模式与串行全量基线(Blocked by: 01)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/02-parallel-mode-and-baseline.md

会话约束:
- 前置确认:票据 01 已 implemented;工作树干净。
- 串行全量基线是本票交付物:过夜后台跑,轮询看输出文件行数,完成后归档 summary 与状态文件——此后所有差分门都对着它,不再有第二遍串行全量。
- 并行差分门通过前不得提交"并行完成"的结论;墙钟与最长 job 耗时必须实测记录。
- 期间不得按进程名批量杀 Godot。
```

## 04 `_delay_dfs` 前缀快照恢复与逐叶子差分门(Blocked by: 03)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/04-delay-dfs-prefix-restore.md

会话约束:
- 前置确认:票据 03 已 implemented 且 profile 报告在案;CombatSession seam 差分测试当前全绿(动 combo_solver 前先跑一遍确认)。
- 语义冻结是红线:字典序、budget、proof_mode、首条成立即返回、失败排序,任何一项要动就停下来找用户。
- 差分 harness 先行:先建 harness 并证明它在旧路径上自洽(变异验证抓到损坏),再接恢复路径。
- 验收只跑定向 test job + harness,不跑全量;最差请求前后耗时对比引用 03 的 profile 数据。
```

## 05 条件票——边探测/路线重放的前缀共享(Blocked by: 03, 04)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/05-conditional-prefix-sharing.md

会话约束:
- 第一件事是触发判定:读 03 的 profile 报告,延迟叶子以外重放点合计 ≤50% 唯一请求耗时 → 本票直接标 wontfix、Comments 记录判定数据、不写任何生产代码。
- 若触发:机制沿用 04 的前缀快照/恢复与差分门,不发明新机制;每个扩展点独立过门。
```

## 06 跨进程结果缓存、analyze 入口修复与 fragment 合并(Blocked by: 02)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/06-persistent-result-cache.md

会话约束:
- 零缓存计数根因已定位(2026-10-02 grilling,见票据 Comments:缓存只在 solve() 查/写,analyze/analyze_manifest 入口不接);开工先核对票据里的修复形态(entrypoint="analyze" 同型 descriptor 接进同一查/存路径),不必重新调查。
- 命中校验与失效沿用现有 descriptor 全等与语义签名;除 analyze 入口覆盖外不改缓存键逻辑,持久化与 fragment 合并照票据 AC 做。
- 去重修复与冷/热门一律走 Tier B(ADR-0006 修订四):compare_summaries 追加排除 combo_cache/solver_profile/mode/appdata,不变量 hits+misses==calls,report_fingerprints 含 keys 逐字段相等。
- 冷/热门用覆盖全部唯一请求的定向子集;收益与 02 基线实测的重复结构(combo 27 请求仅 11 唯一)对比,差异要解释。
```

## 08 全局前置清扫分片(Blocked by: 06)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/08-global-sweep-sharding.md

会话约束:
- 前置确认:票据 06 已 implemented——fragment 格式与合并器是本票的直接依赖;工作树干净。
- 枚举模式开关只走编排器内部传递(先例=票据 04 隐藏回退开关),不进验收参数、不进 --help;枚举跑产物全部丢弃,不进任何门。
- 差分门先行:Tier B 门先在"全缓存命中"的 stub 形态下自洽,再接枚举与清扫扇出;枚举确定性双跑(同树两次 descriptor 序列相等)是第一个验收动作。
- 验收只跑定向 job 子集 + 枚举确定性,不跑全量——全量清扫跑留给 07 终证。
- 饱和度(各车道 busy 占比、三段墙钟)先在定向规模上量出正确形态再交票。
```

## 07 全量终证(Blocked by: 04, 06, 08;05 若实施则加)

```text
/implement .scratch/acceptance-speedup/spec.md .scratch/acceptance-speedup/issues/07-final-proof-and-sharding-decision.md

会话约束:
- 前置确认:04、06、08(及 05 若实施)全部 implemented;分片判定已由 08 前置交付,本票不再有"开分片票"动作。
- 本次全量必须是冷跑且用默认配置(清扫开、全新缓存文件,mode=acceptance-sweep),后台运行并按小时级轮询。
- 墙钟 ≤1h 是整个工程的成败判据:达标则归档证据(Tier B 对拍 + 饱和度与余量推算);不达标则停下向用户报告差距与候选手段,不自作主张追加提速手段。
- 更新量级基线数据到票据 Comments,供后续票据估计验收时长。
```
