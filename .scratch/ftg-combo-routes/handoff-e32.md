# E32 交接（2026-10-08）— 12×20 板中 B 空中段 jC→j214D 同连段收口

**一句话**：E30 完成臂上墙＝**jC startup 7F 恰好吃光 6D 空中出口弧的 7F 剩余滞空**（带几何全程序重叠、active 首帧＝落地帧、取消窗从未开）——`jcs4js1`（jC 7→4＋j214D 9→1）同连段命中 j214D（jC F145、c1 窗 [130,141] 12F、d1 窗 [139,155] 17F、**10/13**、镜像过）；追击 5B 亦同连段命中（L2 [166,168]、BOUNCE F171）→ **11/13**；214C~C 尾仍断（E29 bu 墙族）；joint 89/256。E31「薄身带移」机制在本链不适用（更正）。

## 供设计聊天裁决

1. **jcs/js 组合候选资格**（板中解锁）：代价面＝悬空对空面被 jcs 破坏（prefix 1）、js1 亦损；jcy50 只部分挽救。与 E27 的 js×6A 回归教训同构但机制不同（startup-滞空竞速 vs 玩家落地取消），建议捆绑裁决。
2. **jcy50 独立立项**：地面 G 面 0→8 full（E02 原键！）＋悬空面 10→18＋板中零效应——三面收益分列，与 jcs 解耦。
3. 11/13 追击见证＋89/256 并入 D16 结构性结论；214C~C 尾墙与 E29 bu 值族同墙族合并处理。
4. 机制旗标：E31 的「薄身带移」在板中 D 链上被更正为「startup-滞空竞速」——两条机制在不同面各自成立（悬空/地面面＝带移；板中链＝滞空），阶段 2 记录时分列。

## 关键数字

- 载体参考（nominal c1=140）：prefix 8、jC 未起手（jB 取消窗边界）、F148 MOVE_RECOVERED；c1 重锚 [130,138]（9F）jC 命中 F148＝落地帧。
- jcs4js1：jC 命中 F145、j214D 命中 F155（参考行 d1=147）、BOUNCE_CONTACT F170、追击 5B L2 [166,168]、镜像 10。
- 回归面：A19（悬空 40px）对照 10 / jcy50 18 / jcs4 2(prefix1) / jcs4jcy50 3 / js1 1；GD（E02 原键）对照 0(prefix1, F49) / jcy50 **8 full** / jcs4jcy50 2。
- 门：隔离 27 臂 3 族 0 错；投影审计 9 臂 0 违例（gained 9–12/lost 0）；2,180 回放；diag 20/20 字节全等。

## 复现与试玩

工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e32-20261008/ftgdemo`；分支 `codex/combo-route-prototype-e32-20261008`（实现+证据 `94e2e73`；纯材料快照＝分支头第二提交）；复现命令链 `prototype_e32/README.md`。

```powershell
python prototype_e32/run.py --candidates q-body__L6m60r12v425Cjcs4js1 --output .scratch/ftg-combo-routes/runs/e32-play-jcs4js1 --play
```

输出目录必须尚不存在。对照臂：`q-body__L6m60r12v425C`（jC 命中即死于落地）、`q-body__L6m60r12v425Cjcy50`（地面面修复者）、`q-body__L6m60r12v425Cjcs4jcy50js1`（三元组合）。F3 镜像 / F7 重置；方向键、U/I/K/J＝A/B/C/D、空格跳、G 防。观察点：① jC 提前接触（~F145）与 j214D 落地前扎中的画面；② 弹地与落地前追击 5B（~F167 提交）节奏；③ 214C 仍挥空的断点观感；④ 换 A19/GD 臂体会更快 jC 在对空面上的读感（预期变差）。

## 覆盖缺口（如实）

A19/GD 面 C 起手/距离块/墙侧未扫；jcs3/jcs7、jcy60 细档未测；joint 仅 5 键（链未满 13/13）；jcs4jcy50js1 无共享批投影审计（组件臂各自已审＋isolation 声明级覆盖）；Solver/循环审计未做（无新循环面）；有限回放不作无限性证明。真人全部待试玩。
