# E35 交接（2026-10-08）— 12×20 板边两轮 D 整跑：C 路 12/14 收口（jcs∈[1,4]）；B 路 jC 资格门墙；终缝 214C~C＝E06 复现

分支 `codex/combo-route-prototype-e35-20261008`（实现+证据 `ec62cda`；纯材料快照＝分支头第二提交），工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e35-20261008/ftgdemo`；逐字材料 [round-materials/e35-20261008.md](round-materials/e35-20261008.md)；证据 `prototype_e35/evidence/`（e35-anchors.json 全量台账＋e35-summary.json＋e35-isolation.json 30 id）；复现链 `prototype_e35/README.md`。3,941 次正式回放、隔离 30 id 全过（载具与 E31 逐字节对等）、data_unchanged 全真、基线前后 20/20 字节全等、0 脚本错误、未推送。

## 结论摘要

1. **C 路收口**：`jcs∈[1,4]`（jC startup 7→K）令 jC→j2D 同连段命中（12/14 招）。jcs4 窗：jC [197,197]（1F）／j2D [201,221]（21F）；命中 …6A F178/jB F200/jC F212/j2D F229；镜像通过。机制＝jC 于 jB 命中帧被取消窗消费、startup 在 hitstop 内烧完、active 落解冻首帧（几何在带、目标仍 stun）。joint 12 键 ±2＝14/256（D16 未过）。
2. **B 路墙**：全部声明臂×全部时序 jC 无同连段命中（prefix 恒 11）。机制：jB 命中 F215→hitstop F216–223→缓冲 jC 顺延 F224 执行且 confirmed=False/via_link=False（**失去接续资格**）→资格门整 active 窗失败→F231 目标恢复结束。杠杆（hitstop 内取消消费/缓冲执行规则）＝引擎全局，范围外。
3. **终缝墙**：j2D F229 命中后目标 F241 恢复早于玩家落地 ~F245（落地取消边开启前提）＋214C startup ~10F 双墙；j2m100 俯冲加速（领地内）不动目标侧——**E06 base 终缝结论在 12×20 复现**；h/g 硬直族在领地外。
4. **回归面**：悬空 40px 对空面 control 9/9、jcy50 9/9（无害）、**jcs4/5 0/9（摧毁）**；S1 免疫（control/jcy50 均 full）；base 发布键复现 prefix 13/12＝E06。
5. 校准窗表：B/C 路 stock 臂下 link/C2/cmd2/D2/B2/A/jB 与 E06 发布值逐字相同或更宽；jC/j2D 空（B/C 皆然，C 需 jcs）。

## 提请裁决

① jcs 入 12×20 板边 C 样本组合验证——代价面＝对空面摧毁＋jB 窗碎化，与 jcy50（三面收益）构成权衡矩阵，捆绑裁决；② B 样本 jC 墙解锁需引擎级语义授权（hitstop 取消消费/缓冲资格）；③ 终缝墙与 E06 合并处置（h/g 族 vs 接受「止于 j2D」形态）；④ 14/256 并入 D16 结构性结论。

## 试玩入口（待试玩）

```powershell
# 工作树根目录执行；输出目录必须尚不存在
python prototype_e35/run.py --candidates q-body__refb+jcs4 --output .scratch/ftg-combo-routes/runs/e35-play-jcs4 --play
```

对照 `q-body__refb`（载具：jC 即死于落地竞速）／`base__refb`（旧身体完整节奏）。F1 板中／F2 右墙／F3 左墙镜像／F4 墙距 24／F7 重置；方向键、U/I/K/J＝A/B/C/D、空格跳、G 防。观察点：两轮 5D 节奏小身体可读性；jcs4 下 jC 提前出招读感（对空面变差）；j2D 落地扎中与 214C 挥空断点观感；C 起手整链（少一次 5B 的节奏差）。

## 覆盖缺口（如实）

B 路消费规则差异系黑盒归因（未逐行读引擎消费代码）；joint 仅 C 路；对空面 C 起手/距离块未扫；jcs×L6 载具交互未测（E32 已有板中证据）；Solver 未跑；有限回放不作无限性证明。真人全部待试玩。
