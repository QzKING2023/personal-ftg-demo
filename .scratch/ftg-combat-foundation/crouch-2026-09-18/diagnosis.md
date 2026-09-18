# 蹲姿禁止移动：真人反馈修复

日期：2026-09-18。用户报告目前手感可接受、各项试玩条目通过，但蹲下仍能移动，要求修复。分类：**实现回归（以本次明确修订后的规则为准）**。此前 spec 明写保留水平分量，本次反馈撤回该设计；无需再次提问或调整蹲行速度。

## 复现与诊断

快速入口（项目目录，先建立项目内用户数据目录）：

```powershell
$logs = '.scratch/ftg-combat-foundation/crouch-2026-09-18'
New-Item -ItemType Directory -Force "$logs/runtime" | Out-Null
$env:APPDATA = Join-Path (Get-Location) "$logs/runtime"
& D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --log-file "$logs/engine.log" -s res://tests/test_crouch_stationary.gd
```

先写回归、再修代码。首次完整症状复现见 [red.log](red.log)，退出 1，14 条失败；包含从静止入蹲仍移动和移动中入蹲滑行。最小化到初始静止状态的一帧下前输入，第二次见 [red-minimal.log](red-minimal.log)：`FAIL one frame down-forward from rest: dx=0.722 vx=43.333`，退出 1。去掉下方向成为正常行走，去掉水平分量或不推进帧均不产生此最小症状。

测试前公开的三个假设及预测：

1. 地面移动缺少蹲姿约束：蹲姿已生效仍会按水平轴加速，增加运动约束应让原复现转绿。
2. 蹲姿晚一帧生效：应只有进入首帧滑行，之后停止。
3. 仅是历史惯性：从静止进入不应移动。

最小复现从静止进入即移动，排除 3；完整复现持续 10 帧仍移动且蹲姿已成立，排除 2。核对阶段顺序，输入阶段先设置蹲姿，运动阶段却仍执行普通地面加速，支持 1。只修改自由行动的地面运动分支后，原始与最小用例全部通过；没有清除方向输入或更改加速/摩擦参数。

## 修复边界与结果

- 地面自由行动的 1/2/3 入蹲当帧水平速度归零，持续按住不移动；松开下方向后当帧响应行走。
- 下后仍蹲防，下前不防御；原始方向仍进入历史，双面向 236C 继续识别。
- 限制只作用于主动行走：双面向空中下后不改变跳跃动量，蹲姿被击中时仍产生击退。没有全局清零蹲姿速度来破坏受击行为。
- 新 `test_crouch_stationary.gd` 共 45 条断言；更新旧“允许蹲行”期望，并在训练场输入测试加入 S+后、S+前、行走入蹲及松开 S 的 4 条断言。覆盖实际 `CombatSession.step` 和 Godot 输入映射路径。
- [green.log](green.log) 的专项结果退出 0。全量入口：`./tools/run_acceptance.ps1 -Output '.scratch/ftg-combat-foundation/crouch-2026-09-18/final'`。
- [final/summary.json](final/summary.json)：**12 套件、1504 条 PASS，全部退出 0、脚本错误检查 0**；另有资源导入、输入诊断、300 帧主场景检查通过。Solver 路线、真实输入回放、空间及循环套件均通过，未增大命中数或总时长限制。已有空间验证范围没有扩大。
- 引擎的离线系统证书警告、非法资源负例的预期报错与此前相同，不冒称全部输出零错误。没有添加临时运行时日志。

已同步 CONTEXT、spec、规则讨论、操作说明、行为数据、README 与 issue16。真人反馈属于用户报告，没有代填外设、试次数或成功率；本修复后的真人复玩尚无反馈。此次修复无待决策项；此前独立的实现缺口和防御硬直规则问题继续保留在联合验收报告中。
