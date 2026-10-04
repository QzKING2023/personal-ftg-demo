# 可变 manifest 的带外重放缺口

Status: needs-triage
Labels: ready-for-agent
Type: task

## 问题

全量 sweep（pool 模式）下，test_move_table 的 2 条 `analyze_manifest` 请求稳定被
「重建请求不相等」拒绝并如实记 failed/gap：stub 枚举阶段捕捉的 descriptor 内嵌
`table_content_digest` 对应 manifest 的**盘中中间态**，而清扫阶段的 worker 带外
重放时重读同一文件，读到的已是测试写完的**终态**——重建 digest 必然不同。

受影响 digest（2026-10-04 全量跑，`.scratch/solver-p7-01/acceptance-full/`）：

- `75f69122738e286e…`（worker-02 task-8，0.03s 即拒）
- `d0497e27a2df2ca2…`（worker-07 task-11，0.03s 即拒）

同族但已修复的第三条（`5aa13ff7…`，complete 重建漏 plumb）见 ADR 0006 修订七
与 solver-guide P7 节；本票只管 manifest 盘中态这一类。

## 复现

```
python tools/run_acceptance.py --sweep --only test_move_table \
  --output .scratch/solver-p7-01/sweep-mt-repro \
  --cache .scratch/solver-p7-01/sweep-mt-repro/cache.cache
# sweep.json: covered=…, gaps 含 75f69122/d0497e27；worker-g0.log 有
# SWEEP_WORKER_RESULT … "error":"重建请求不相等（重建 digest=…）"
```

## 期望

- 热跑阶段 job 内就地现算已经兜底正确性（job 断言结果不受影响），行为符合
  ADR 0006 修订四（gap 如实记录，不判死）——本票不改这个纪律。
- 要消除的只是**确定性缺口**：候选方向包括枚举侧冻结 manifest 快照
  （descriptor 旁车存表文本或拷贝文件，重放读快照），或对 manifest 路径类
  请求在枚举后标记 replay-unstable、单请求单进程就地算。
- 无论取哪条，spawn/pool canonical 缓存逐字节对拍门必须全过；修复不得
  改变请求键语义（table_content_digest 仍须反映真实被求解的表内容）。
