# handoff-e28 — E28（弹地追击尾缺口族）交接

2026-10-08。轮 J（编排方指派；fork 执行）。轮材料全文：[round-materials/e28-20261008.md](round-materials/e28-20261008.md)。分支 `codex/combo-route-prototype-e28-20261008`（自 e27 头 `ad94944` 分叉；实现+证据 `04d88f5`，纯材料快照 `daa4a86`）。未推送；共享账本未动；用户未提交材料保持原样。

## 一句话结论

**指派两杠杆均死：pr（j214D recovery）是死参数——空招落地即作废、恢复段从不结算，−1/−2/−3F 与 js2 逐字节相同（8/8 链批）且与 e0 回归六键全等；有效玩家延迟＝全局落地恢复（3+1）。bw＝全局常量 16（未触碰）且量化不足——有效追击窗仅 ~3F（F171–174），对任何追击招的结构缺口 ~8F（E27「1–2F」系自由帧口径，已再修正）。E05 空中段同连段上限 10/13；但 witness（跳 jC）形态取得家族首个同连段弹地追击命中（缓冲 L2=154–156 → 5B 命中 F165、combo 9→10），尾断于 214C 0/75（D45-la 目标 ~F181 空中受身）＝5B AIR 资料族墙。**

## 供设计聊天裁决

1. **追击缺口杠杆全在全局参数**：GROUND_BOUNCE_FOLLOWUP_WINDOW_FRAMES（16）与落地恢复（3+1）——是否授权 E16 式隔离单行臂（game_params 补丁、双 SHA manifest）另立项；量化门槛 ≈+8F 当量。
2. **witness 尾墙＝5B AIR 资料**（D45 值 18/24）vs 214C 时序/触及——是否开 5B AIR untech/上抛阶梯新声明；witness 形态（跳 jC）是否值得作为独立短路线与原链比较（E27 旗 ③ 延伸：现已带同连段追击命中）。
3. **E27「1–2F 缺口」修正为 ~8F**（对追击命中口径）；E25「双因」→单因（E27）→窗量级（E28）三级修正链归档。
4. js 捆绑回归（E27 旗 ①）不变：采纳 js≤2 须同时重锚 6A 对地路线。

## 本轮硬数字（速查）

- 时间线（base__js2 traced）：j214D HIT F162（y439.2）→落地/弹地接触 F171 →窗尽 F174 →自由 ≈F175 →5B 最早命中 ≈F182。
- pr 惰性：js2pr21/js2pr19 ≡ js2（8/8 批逐字节）；pr21/20/19 ≡ e0（六键 jump[4,18]/C[22,22]/D[27,32]/B[71,73]/k214[79,92]/tildeC[103,119]）。
- witness：j214D 15 档（d1x 131–145）；追击 5B 同连段 3 档（L2 154–156，命中 F165）；214C 0/75（166–190×3）。
- 全链追击：0/47（L2 f_j2+2..+48，base/q-body × js2/js2pr20/js2g28h22/js2pr20g28h22）。
- 门：隔离 26/26；三元组 0 违例（151×3×2＋47×3＋1 行）；基线前后 20 traces＋日志逐字节全等；0 脚本错误；2,872 次回放。

## 证据与复现

- 结论级：分支 `prototype_e28/evidence/`（e28-isolation、e28-triple-audit-{regress,l2,cal}、e28-baseline-traces、e28-pr-inertness、e28-witness-r2-{base__js3,base__js3g28h22}、e28-anchors、manifest SHA256）。
- 原始（未入库可复跑）：工作树 `.scratch/ftg-combo-routes/runs/e28-*`。
- 复现命令与试玩入口：分支 `prototype_e28/README.md`。

## 遗留

- 全链 r2 细扫（窗内无 5B 命中、无从锚）；joint/256（链未满）；witness 仅 base；Solver/循环审计未做。
- 真人手感全部待试玩（AIR 缝 3F、6D 读点、witness 缓冲追击节奏、214C 挥空观感）。
