# TEMPORARY RV-E11 · 原版边两轮普通 D 之后改用其他终点招式（未修改基线调查）

【临时实验代码】仅存在于实验分支 `codex/combo-route-prototype-rve11-20261011`（自 `5ada3ba109d28021de97706a9adb118b934645be` 切出，含 prototype_rve02/ 全套实验库与证据），不并入正式实现。方向 C：零参数改动——不改任何资料/规则，只调查"原版边两轮普通 D 前缀 + 改用其他终点招式（或调整末段连接）"能否在未修改基线上连续成立并按 D111 保位。D97/D111 五项裁决口径不变，裁决的"序列"按候选终点改写。设计裁决（终点比较与取舍）归设计聊天，本目录只交证据。

## 结论速览

- **接地倒地能力普查**（全表 23 招式 hit_profiles）：能造成实际普通倒地（D93 口径）的只有 3 个——`214C~B`（接地 normal/counter → GROUND_KNOCKDOWN 30F，直接倒地）、`214C~C`（接地 → GROUND_KNOCKDOWN；空中 → DOWNWARD_SLAM 触地转倒地；RV-E02 对照）、`2C`（接地 → LOW_FLOAT_SWEEP 20N/26N 浮空，触地转普通倒地 30F）。其余全部是眩晕/LAUNCH/SLIDE/BOUNCE 或对地无资料（详见 summary.md 普查表）；表中不存在 3C。
- **可达性**（接地语境、从原版边末段声明边出发）：倒地能力可达者仅 `5B > 214C > 214C~B`（新候选）、`5B > 214C > 214C~C`（对照）、`5B > 2C`（链式取消）。5D 只声明 hit_link 5B——"5D→214C 直连"缺边；5D/5B 自身无倒地资料，"删终缝以 5D（或 5B）收尾"资料即证不成立。
- **实测（参考站位 g9.3/r6.7/facing=1，前缀层与 rve02 同锚点全过）**：
  - **C 起手 + 214C~B：终缝 0/66 按压帧同连段命中，结构差 1F**。214C 命中 F158（r2∈{138,139} 不变——首个 active 帧几何锁定）、目标恢复 F173（+15 = 眩晕 7N+8F 停顿）；Rekka 派生不接受接触前预输入（F143–F158 按压不锁分支，Rekka 窗以接触打开），最早起手被停顿锁死在 +9 → ~B 最早命中 +16，恒晚 1F，输入无解。假阳性形态：~B 命中 F174 为新连段第 1 击且当帧 KNOCKDOWN。
  - **C 起手 + 2C：终缝 0/25（含 hit-5..hit-3 接触前预输入最优）**。5B 命中 F142、恢复 F158（8N+8）；2C 最好命中 = 前击+8+startup(+9) = +17，差 1F；停顿内/之后按压退到 +18 差 2F。假阳性：2C 新连段命中 F160 → LOW_FLOAT_SWEEP → 触地 F178 转 KNOCKDOWN。
  - **B 起手 + 214C~B：断缝 A（r2 层 0 候选）**——5B#9→214C 结构墙与终点选择无关（RV-E02 已在 108 站位全证，本轮参考站位复现）；diag 全视野存证双假阳性链（214C F170、~B F186 均为新连段命中，F186 KNOCKDOWN）。B + 2C 差 3F。
- **结构规律（供 RV-E09 候选映射）**：带预输入的取消链命中 = 前击+8F 停顿+startup，连通条件 = startup ≤ 目标剩余眩晕帧；路线深处眩晕 floor 6–8N，startup 8（5C/6A/214C）恰同帧可连，startup 9（2C）差 1F；Rekka 派生因"接触才开窗、不预输入"比同 startup 的取消链晚 1F（~B 有效 offset +9+7=+16 vs 214C 后恢复 +15）。
- **全域复核**：C+rekka_b 双面向 × 5 站位、C+2c facing=1 × 5 站位全部断在同一终缝（0 候选）；失败与站位/面向无关（命中偏移是帧算术，与 rve02 的域外对照结论同构）。
- 0/全部条件完整成立（D97/D111 序列按候选改写口径）。**无连通候选 → 不适用键窗 ±12 / OTG 负例抽查（任务 (b) 仅对连通候选要求）；假阳性倒地形态已逐帧存证。**

## 复跑（PowerShell，仓库根 = 本工作树）

首次先初始化类缓存（新工作树必做）：

```powershell
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --editor --path . --quit
```

然后按序（输出落 `prototype_rve11/evidence/`；并行引擎进程须各自独立 APPDATA）：

```powershell
# 主候选连通性（参考站位）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=C ender=rekka_b facing=1 mode=ref
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=B ender=rekka_b facing=1 mode=ref
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=C ender=2c facing=1 mode=ref
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=B ender=2c facing=1 mode=ref
# 站位复核（5 站位 × 指定面向）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=C ender=rekka_b facing=1 mode=spots
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=C ender=rekka_b facing=-1 mode=spots
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_scan.gd -- kind=C ender=2c facing=1 mode=spots
# 终缝逐帧探测（结构性 1F 缺口的账目表）
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_probe.gd -- kind=C ender=rekka_b
& 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe' --headless --path . -s res://prototype_rve11/rve11_probe.gd -- kind=C ender=2c
```

`rve11_window.gd` / `rve11_negative.gd` 已就位但本轮未运行——二者依赖 scan JSON 中的成立锚点，本轮无连通候选（运行会因缺 anchors 失败，属预期）。

## 脚本与证据

| 文件 | 内容 |
| --- | --- |
| `rve11_lib.gd` | 共享库：复用 rve02 站位/输入原语；候选终点序列（rekka_b/2c/rekka_c 对照）；tb（Rekka B 新按下）与 e3（C+down 同帧，2C 按按下帧蹲姿判定选招）输入键；回放含逐帧木桩状态迁移日志；D97/D111 裁决（序列按候选改写）；时序账目提取 |
| `rve11_scan.gd` → `scan-{kind}-{ender}-f{±1}-{ref,spots}.json` | 层搜索（前缀与 rve02 逐键一致 + 终点层），断点诊断含命中/起手帧、END 后新连段命中、状态迁移账目 |
| `rve11_probe.gd` → `probe-{kind}-{ender}-f1.json` | 终点键宽范围逐帧探测：每按压帧的派生起手/命中/是否同连段/恢复日/倒地日——"0/N 同连段命中"的结构性证据表 |
| `rve11_window.gd` / `rve11_negative.gd` | 键窗 ±12 双口径与 OTG/早晚/删 5B 负例（本轮无连通候选，未运行，留作候选成立后复用） |

## 已知限制

- 计划字典每帧一条输入：tb/e3 按压帧避开 r2 指令块（r2+8..r2+32 / b3+1..b3+17 与 r2 块 r2-3..r2 无交叠）；probe 的 2c 早段（press ≤ b3+4）会覆盖 b3 的 5B 按压，属探测伪影，已在 summary 中标注，不作为证据引用（其诊断行仍自洽）。
- 本轮零参数改动：候选缺口的"参数映射"（眩晕+1、startup−1、派生预输入等）只列为 RV-E09 输入，未实测。
- B 起手全域不成立沿用 RV-E02 的 108 站位证明（同一条缝 A），本轮仅在参考站位复现；C 起手站位复核为 5 站位 × 双面向（rekka_b）/ 1 面向（2c），非全 D106 域——缺口为帧算术不变量，与站位无关（rve02 域外对照同构结论）。
- 被防/挥空对取消资格的 gating 未测（与 RV-E02 同界，归 RV-E09）。
