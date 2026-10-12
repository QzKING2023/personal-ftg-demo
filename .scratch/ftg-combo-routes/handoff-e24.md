# handoff-e24 — E24（Q48：D 空中击飞高度族＋时序对照）交接

2026-10-08。并行轮 G（编排方指派；fork 执行）。轮材料全文：[round-materials/e24-20261008.md](round-materials/e24-20261008.md)。分支 `codex/combo-route-prototype-e24-20261008`（工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e24-20261008/ftgdemo`；实现+证据与纯材料两提交见下）。未推送；共享账本未动；用户未提交材料保持原样。

## 一句话结论

**轨迹单变量（5D/5[D] 空中击飞 170→260/340/425）对 D→5B 零收益且结构性反效（untech 池固定、抬高只换滞空/空中受身）；u56/r12 复现 E20-R2；但组合臂 v425Cr12＋L6 声明束打开 AIR 缝（base midB [89,91]/q-body 墙 [76,78]，3F）并首次实测 6D 对浮空目标命中＋jB——E05 的前半阻塞被打通，jC 成下一堵墙（jB 空中浮空量，新变量族）。**

## 供设计聊天裁决

1. **Q48 表第 3 行裁**：D 空中击飞高度单变量不作为 D→5B 修复（否定证据＋机制）；与 u56（地面缝、3F [101,103]）/r12（地面缝、3F [89,91]）的取舍＝「时序侧独立成立、轨迹侧仅组合有效」。
2. **组合臂 v425Cr12 是否进入组合验证**：AIR 缝＋D45 LAUNCH 再挑空＋6D 接入＋jB 已证；代价＝两重未裁决依赖（v425 观感、r12 被防面）＋jC 立墙。若采纳方向，需立项 jB/jC 空中资料浮空量（新变量族）才能到 E05 完整样本。
3. **q-body（D51 尺寸）midB 缝被 5[D] 位移穿越阻断**（F82 SWITCHED_SIDES，q-v 同构）——D51 言明不豁免；需击退/位移族或 236C 侧（E23）配合，本轮未解。
4. L6 束携带五前提（D45/D47/D49/E02 边）全部「声明未裁决」——本轮证据不得视为其中任何一项被采纳。

## 本轮硬数字（速查）

- base midB 缝：e0/v 系＝无；u56 [101,103]；r12 [89,91]；**v425Cr12+L6 AIR [89,91]**。q-body midB 全无（穿越）；q-body 蓄力墙：u56 [88,90]、r12 [76,78]、v425Cr12 AIR [76,78]。
- 机制行（base midB trace）：D 命中 F73（y428.7、stun 20）→ e0 落地 F93/恢复 F101/D 收招 F106；v260C 落地 F97/恢复 F101；v425C 落地 F106/F101 AIR_RECOVERED。
- 6D 链（base v425Cr12，锚 b0=90/d6=102）：5B air F100（y413.3）→6D F118（y423.3）→jB F132（y423.8）→jC 挥空 F148（y437.7、stun 2）。q-body（墙，b0=77/d6=84）：至 6D prefix 7。
- solo（base e0）：普通 [32,34]/蓄力 [38,40] 全通（E04 复现）；v260D 两源仍在；v340D 断普通源；v260C 断蓄力源。q-body 仅墙向普通源 [32,34]×单向。
- u56 距离边界：gap 0/6/12 通、≥24 断（E11 复现）；四键联合 61/256（f1）。
- 规模：主 32,796＋L6 约 3,300 次回放；隔离 34 臂全过；三元组 0 违例；基线前后 20 traces SHA 全等；0 脚本错误。

## 证据与复现

- 结论级：分支 `prototype_e24/evidence/`（23 文件＋manifest SHA256：isolation、triple-audit main/l6、main/ 18 候选＋summary、l6-anchors（含 b/c 相位 chosen/final）、diag 前后 summary）。
- 原始（未入库可复跑）：`.scratch/ftg-combo-routes/runs/e24-{main,l6a,l6a-b,l6a-c,diag-before,diag-after,smoke,play-smoke*}`（工作树）。
- 复现命令与试玩入口：分支 `prototype_e24/README.md`。

## 遗留

- v340Cr12/v260Cr12 未测（组合最小充分性缺口）；jC 超 ±10 未扫；r 臂被防面未量化；Solver/循环审计未做。
- 真人手感全部待试玩（AIR 缝 3F、6D 读点、jC 挥空观感、v425 击飞画面、r12 风险面）。
