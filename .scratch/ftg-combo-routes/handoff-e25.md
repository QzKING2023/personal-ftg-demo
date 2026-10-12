# handoff-e25 — E25（jB/jC 浮空量族，E24 AIR 缝载具）交接

2026-10-08。轮 G 续轮（编排方指派；fork 执行）。轮材料全文：[round-materials/e25-20261008.md](round-materials/e25-20261008.md)。分支 `codex/combo-route-prototype-e25-20261008`（自 e24 头 `6775df9` 分叉；实现+证据与纯材料两提交见下）。未推送；共享账本未动；用户未提交材料保持原样。

## 一句话结论

**E24 的「jC 墙」是锚定伪影——重锚 (b1,c1) 后未改动的载具上 jC 大面积接通（base 112/169 格、q-body 59/169）；真墙移至 j214D（起手被钉在 jC 恢复点＋startup 9F×池尽×几何挥空，均不在本轮 jB/jC 浮空量族内——该族在全测面上行为惰性：9 臂 grid 逐字节相同、三元组 0 违例）。E05 空中段推进至 `…> 6D > jB > jC`，断于 j214D。**

## 供设计聊天裁决

1. **E24 结论修正**：「jC 挥空＝jB 空中浮空量新变量族」应撤销，改为「jC 重锚可通；j214D 缝为当前真墙」。
2. **j214D 缝候选杠杆排序**（需新声明范围）：j214D startup 9F（单键、量级匹配缺口 ~5F）；jC AIR untech（+12→×缩放 ≈+5.6F，边缘）；水平推离/判定带族（几何挥空因）。三者都超出本轮指派的 jB/jC up/untech 声明。
3. jC 2D 窗（b1×c1 联合，base 命中区 b1[115,127]×c1≈+4..+13）与 D15 单键±3 口径的关系——需口径裁定，不擅自当通过。

## 本轮硬数字（速查）

- AIR 缝（载具，E24 复现）：base midB b0∈[89,91]；q-body 蓄力墙 [76,78]（E24 值，本轮 grid 全部在 b0=77 上成功为隐式复现）。
- jC 命中区：base 112/169 格（93 存活）、b1∈[115,127]、c1≈b1+4..+13；q-body 59/169（50 存活）、b1∈[102,113]、c1≈b1+4..+9。
- 6D 链参考（base e0，b1=125/c1=129/d6=102）：5B(air) F100 → 6D F118 → jB F132（y423.8）→ jC F147（y431.8、stun 9）→ 存活至 F153–164。q-body（b1=113/c1=117）：jB F120 → jC F135（y462.2）。
- j214D 墙：d1∈[143,163] 全部钉死 start F160/161（一档 F147）；startup 9；最早 active F156（该行目标浮空受击至 F160 仍无接触事件）＝几何挥空；x 间隔全程 ~50px 恒定。
- 惰性证明：9 臂×2 载体 grid 逐字节相同（169 格）；三元组门控 1,320+888 行 0 违例、gained={}；jc120 的 jC 命中 y 仅 +0.6px（轨迹缩放 ≈0.47）。
- 规模：4,006 次回放（cal 546＋grid 3,042＋d1 378＋neg 40）；隔离 20/20；diag 前后 20 traces SHA 全等（boundary 10/0、replay10 103/2、symptoms 13/24 已知态）；0 脚本错误。

## 证据与复现

- 结论级：分支 `prototype_e25/evidence/`（e25-summary.json 含 jC 区/墙机制/负例/回放计数、e25-isolation.json、e25-triple-audit.json、diag 前后 summary、manifest SHA256）。
- 原始（未入库可复跑）：工作树 `.scratch/ftg-combo-routes/runs/e25-{cal,anchor-grid,anchor-d1,anchor-neg,diag-before,diag-after,play-smoke}`。
- 复现命令与试玩入口：分支 `prototype_e25/README.md`。

## 遗留

- j214D 判定带逐帧解析未做（几何结论由无接触事件+x 恒定间接承载）；追击尾 L2/r2/rk2 与 joint/256 因 j214D 未通而未扫；j214D-off-jB（跳过 jC）机制 witness 未测。
- 真人手感全部待试玩（AIR 缝 3F、6D 读点、早 jC 节奏、j214D 挥空观感）。
