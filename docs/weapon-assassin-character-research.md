# 武器型刺客角色研究

> 研究日期：2026-09-21  
> 状态：参考材料，不构成正式规格，也不改变当前运行时规则。  
> 范围：ACGN 中的刺客型角色，以及 FTG 中使用短刀、匕首、蝴蝶刀或其他武器的相关先例。

这份文档整合前两轮研究，供后续角色、招式和战斗系统讨论参考。主题是 ACGN 与格斗游戏中“使用短刀、匕首、蝴蝶刀或其他武器战斗的刺客型角色”。文档记录的是先例、共同规律和差异轴，不是一个可以直接照搬的角色方案。

## 研究范围与阅读方式

资料优先采用官方角色页、开发者访谈、招式手册、补丁说明和平台官方介绍。格斗游戏中的角色页面经常随版本变化，本文记录的是它们在设计上呈现出的稳定关系，而不是某一版本的平衡结论。

“刺客型”在这里有两个层次：

- **身份层**：角色在设定中被称为刺客、忍者、杀手、执行者、盗贼或情报人员。
- **战斗层**：角色通过难以预测的接近、短时间爆发、资源化武器、空间控制或快速脱离来组织战斗。

两者不一定重合。Nina Williams 是明确的 Silent Assassin，但主要依靠暗杀术、枪械和空手连段；Kano 使用蝴蝶刀，却更接近黑帮雇佣兵；Narmaya 使用太刀，却通过架势切换体现出非常清晰的刺客式接近与压制。因此，比较案例时需要同时标记“刺客身份”和“武器系统”，避免把所有持刀角色都归为同一类。

## 一、刺客型角色的共同核心

刺客型角色的共同核心不是“拿匕首”和“穿黑衣”，而是改变冲突发生的条件：谁先得到信息、谁决定接触距离、谁控制警戒升级，以及一次行动结束后能否脱离现场。

潜入类游戏经常把这一过程概括为“观察—计划—执行—反应”。《Mark of the Ninja》的开发复盘明确使用了这四步，并强调同一场遭遇应当有多种成立的解法。[Game Developer：Stealth in 2D](https://www.gamedeveloper.com/design/stealth-in-2d-design-lessons-from-i-mark-of-the-ninja-i-)

在格斗游戏中，双方始终互相看见，真正的潜伏阶段被压缩成每次交手中的数秒。因此可以把它翻译成：

> 读对手 → 条件化接近 → 短促执行 → 重置距离或继续追击

“避免正面冲突”在 FTG 中通常不意味着完全不接触，而是避免进行可预测、可持续的伤害交换。刺客感会落在以下几种条件控制上：

| 被避免的对象 | 在动作或格斗游戏中的常见体现 |
| --- | --- |
| 被识别 | 伪装、社会身份、混入人群、角色假动作 |
| 处于同一空间 | 高低差、墙体、墙跑、钩索、传送、侧换 |
| 让敌人形成完整判断 | 噪声诱导、烟雾、诱饵、假目标、光线控制 |
| 让冲突升级 | 非致命处理、陷阱、事故、优先处理关键目标 |
| 承受行动后果 | 藏匿、撤离、换位、武器回收、重置中立 |

《刺客信条》把人群、噪声、藏身点、烟雾、环境和移动群体都当作战斗动作；《Shadows》还让玩家熄灭灯笼、利用雨雾、诱导敌人、拖走目标，并在失误后面对“调查—搜索—警戒”的连续压力。[刺客信条潜行演变](https://news.ubisoft.com/en-gb/article/1hges9IWLOmNAFpiavYmKl/the-evolution-of-assassins-creed-stealth) [Shadows 潜行玩法](https://www.ubisoft.com/en-gb/game/assassins-creed/news/1lmnk4XTnnqRh1foViGYPR)

这种设计还需要清晰的失败阶段。敌人从未察觉到可疑、调查、警戒和追捕的变化，应当可通过动作、音效或界面被读出；否则“谨慎接近”会变成不可学习的随机惩罚。《Dishonored》的设计访谈也强调敌人应处于连续的不确定状态，而不是简单的“知道/不知道”。[Dishonored 创意总监访谈](https://blog.playstation.com/archive/2012/08/21/interview-dishonoreds-harvey-smith-reboots-the-stealth-genre/)

## 二、战斗方式的共同模式

### 1. 先手与信息优势

刺客通常不以长时间正面换血作为优势，而是先读取对手、路线或资源，再选择一个较短的有效窗口。Hitman 将目标规律、伪装权限、道具和事故组织成沙盒谜题；Sekiro 则把未被察觉的处决、高处攻击和义肢工具组合成不同的起手方式。[IO Interactive《Hitman》](https://ioi.dk/hitman?panel=hitman/content/game-modes) [Sekiro 官方手册](https://www.fromsoftware.jp/manual/sekiroshadowsdietwice/stadia/action2.html)

转译到 FTG 后，先手优势往往表现为：

- 让对手难以确认接近高度、方向或时机；
- 让对手必须先回应投射物、设置物或姿态变化；
- 通过一次命中获得短时间的连续行动权；
- 命中确认失败时迅速退出，而不是继续赌更长的连段。

### 2. 低承伤、高爆发和高机动

刺客常见的风险回报关系是承伤能力有限，但接近成功后的收益较高。其强度来自选择正确的进入时机，而不是在任何距离都能稳定作战。

### 3. 进入与退出同样重要

《英雄联盟》对 Talon 的重做目标包括延缓瞬间爆发、增强接近与逃脱灵活性、强化游走，并用墙面和城市跑酷构成角色身份。[Riot：Talon 设计回顾](https://nexus.leagueoflegends.com/en-us/2017/01/dev-state-of-champion-update-january-2017/)

这也是格斗游戏中“刺客”和普通高速角色的区别之一：移动不只用于接近，也用于命中后的重置、再次切入和规避反击。

### 4. 警戒和失败仍然要有可玩性

潜行失败后直接变成普通战士，会让前面的系统失去意义。较好的先例会保留撤退、换位、资源回收、假动作或风险更高的补救路线。FTG 中对应的表现可能是：进攻被防住后仍有退场选择，但退场本身有明显代价。

## 三、武器如何形成角色记忆点

普通匕首通常只提供“短、快、隐蔽”三种印象。更有辨识度的角色，会让武器参与到战斗循环中，而不是只把它当作攻击动画里的装饰。

| 武器层面 | 常见惯例 | 形成差异的方式 |
| --- | --- | --- |
| 携带位置 | 腰间、靴中、袖内 | 与手腕、手指、前臂或特殊姿态绑定 |
| 出刀方式 | 拔出、刺击、投掷 | 翻腕、折叠、旋转、弹出、回收 |
| 形态 | 单一固定刀刃 | 钩刃、双刃、可发射刀、刀与工具转换 |
| 作用 | 造成近距离伤害 | 改变路线、固定位置、切断路径、制造诱饵或第二攻击点 |
| 反馈 | 命中与收刀 | 独特动作节拍、摩擦声、轨迹、特效或可学习的声音 |
| 代价 | 默认一击必杀 | 有限库存、充能、掉落、回收压力、暴露风险或状态消耗 |

《刺客信条》的隐藏刀从袖内弹簧刀逐渐扩展为钩刃、旋转刀、腕载弩和多功能护臂。它的变化重点不是单纯提高伤害，而是改变移动、攀爬、拖拽、远程投射和撤离路线。[隐藏刀演变史](https://www.ubisoft.com/en-gb/game/assassins-creed/news/5stMcqLQzQ3mckEsP9Aevo/the-evolution-of-assassins-creeds-hidden-blades)

《VALORANT》的武器设计资料提供了一个适用于匕首的通用原则：武器需要有一眼可辨的视觉标记，并有可学习的动画节拍、音效和特效语言。[VALORANT 武器设计](https://playvalorant.com/en-us/news/dev/how-the-valorant-arsenal-was-built/)

## 四、FTG 中最有参考价值的先例

### A. 严格或接近短刀刺客

**Seth（《UNDER NIGHT IN-BIRTH》）**

官方身份是“无形的刺客”，武器为双剑 Eliminator。招式集中在突进、空中接近、快速下降和脱离。[官方角色页](https://www.arcsystemworks.jp/uni2celes/en/character/seth.php) [官方招式说明](https://www.arcsystemworks.jp/uniclr/manual-ps4/en/character/seth.html)

战斗体现：以瞬间出现和迅速离场取代站桩对砍。

记忆点：双刃、空中后撤和“出现—命中—消失”的节奏绑定在一起。

**Taki（《Soulcalibur》）**

Taki 使用忍刀，战斗围绕贴身距离、姿态转换和持续压迫展开；官方调整资料还记录了腰间 Mekki-Maru 的近距突进、削防和转入 Possession 架势。[官方战斗调整资料](https://media-center.bandainamcoent.eu/games/soulcalibur6/sc6_battle-adjustment200.pdf)

战斗体现：接近成功后不立即结束，而是通过刀的距离和姿态持续消耗防守。

记忆点：腰间武器位置、贴身削防和忍者式架势变化。

**Chipp Zanuff（《Guilty Gear -Strive-》）**

Chipp 的武器是手甲刃，官方将他定义为高速忍者和 Rushdown 角色。[官方角色页](https://www.guiltygear.com/ggst/en/character/chp/)

战斗体现：墙跑、空中手里剑、高速突进和多方向接近。

记忆点：短刀不再代表“安静”，而代表速度、连续位移和高风险切入。

**Maya（《Killer Instinct》）**

Maya 使用两把远古匕首。官方介绍中的 “blade juggling” 让匕首在被防御后充能；失去一把后，能力会下降，必须重新找回。[Xbox 官方介绍](https://news.xbox.com/en-us/2014/09/18/games-killer-instinct-season-two-maya/)

战斗体现：投掷、回收、充能和继续压制构成完整资源循环。

记忆点：匕首具有库存、位置和状态，而不是始终安全地握在手里。

**Ibuki（《Street Fighter V》）**

Ibuki 的苦无数量有限，使用后需要补充；苦无、空中苦无和烟雾弹共同控制中立和起攻路线。[Capcom 角色页](https://game.capcom.com/cfn/sfv/character/ibuki?lang=en) [Capcom 招式表](https://game.capcom.com/cfn/sfv/character/ibuki/movelist?lang=en)

战斗体现：通过有限投射物逼迫对手移动，再利用不透明的接近路线发动攻击。

记忆点：苦无库存和烟雾弹让角色的“刺客工具”变成节奏管理系统。

### B. 武器状态与姿态型

**Vega（《Street Fighter》）**

Vega 使用三爪，拥有墙跳、空中攻击、面具以及持爪和卸爪状态。官方招式表明确区分了 claw-on 与 claw-off 招式。[Capcom 角色页](https://game.capcom.com/cfn/sfv/character/vega?lang=en) [Capcom 招式表](https://game.capcom.com/cfn/sfv/character/vega/movelist?lang=en)

战斗体现：持爪时强调距离和速度，卸爪后战斗方式改变。

记忆点：武器是否仍在身上，会改变角色的招式语言。

**Narmaya（《Granblue Fantasy Versus》）**

Narmaya 使用太刀，但核心是 Dawnfly 与 Freeflutter 两种架势。收刀与拔刀状态分别影响攻击距离和压制方式。[官方角色页](https://granbluefantasyvs.com/characters/narmaya/)

战斗体现：玩家持续在安全距离、近距离压制和架势切换之间选择。

记忆点：拔刀动作本身就是角色的模式转换。

**Cody（《Street Fighter V》）**

Cody 的刀会改变普通攻击与特殊技；投出刀后，他会暂时回到徒手状态。[Capcom 角色页](https://game.capcom.com/cfn/sfv/promotion/cody?lang=en) [Capcom 招式表](https://game.capcom.com/cfn/sfv/character/cody/movelist?lang=en)

战斗体现：持刀和空手之间存在明确的战术取舍。

记忆点：武器持有状态直接改写中立，而不是只改变必杀技外观。

### C. 空间化与多点攻击型

**Sadira（《Killer Instinct》）**

Sadira 将刀刃、蜘蛛丝、墙面和空中移动组合起来。[官方角色页](https://www.ultra-combo.com/characters/sadira/)

战斗体现：先用丝网或墙面改变位置，再从空中或侧面接入刀刃攻击。

记忆点：蜘蛛丝和刀刃组成一个空间系统，角色不再只是地面上的短刀战士。

**Kimberly（《Street Fighter 6》）**

Kimberly 将喷漆罐变成 Shuriken Bomb、彩烟和换位工具，并在场上留下涂鸦。[Capcom 官方介绍](https://news.capcomusa.com/2022/08/07/the-newcomer-ninja-kimberly-and-thrill-seeking-juri-joins-street-fighter-6/)

战斗体现：道具可以提前布置，再用彩烟或喷罐完成伏击和换位。

记忆点：现代城市媒介、彩烟和涂鸦取代了传统黑衣忍具。

**Zato-1（《Guilty Gear -Strive-》）**

Zato 使用影子和傀儡 Eddie 作为第二行动主体。[官方角色页](https://www.guiltygear.com/ggst/en/character/zat/)

战斗体现：本体和影子可以从不同位置同时制造攻势。

记忆点：刺客武器被外化成一个可独立行动的伙伴。

**Hazama（《BlazBlue》）**

Hazama 使用 Ouroboros 链刃在场上拉近和换位；其官方设定强调他厌恶冲突，却会优先完成任务。[官方角色页](https://www.blazblue.jp/bbrr/sp/character/hazama/)

战斗体现：武器既是攻击手段，也是移动锚点。

记忆点：链刃带来的空间折线比刀本身更容易被识别。

### D. 身体化或职业工具型

**Millia Rage（《Guilty Gear -Strive-》）**

Millia 被官方称为“Forbidden Hair Assassin”，把头发直接变成武器。[官方角色页](https://www.guiltygear.com/ggst/en/character/mll/)

战斗体现：头发形成大范围、可设置、可从不同角度出现的攻击弧线。

记忆点：刺客武器改变了角色轮廓和动作，而不是挂在腰间。

**Valentine（《Skullgirls》）**

Valentine 使用手术刀、毒针和医疗器械。不同毒剂会带来持续伤害、硬直或输入干扰。[官方角色指南](https://skullgirls.com/guides/Skullgirls_CharacterGuide_EN_X360.pdf)

战斗体现：投射物、近身手术动作和毒剂状态之间互相转换。

记忆点：职业工具同时承担武器、身份和状态系统三种功能。

**Ciel（《Melty Blood: Type Lumina》）**

Ciel 使用 Black Key，既能投掷，也能进行近距离突刺和空中控制。[官方指令表](https://meltyblood.typelumina.com/resources/img/command/meltyblood_typelumina_all_command_lists_en.pdf)

战斗体现：远程测距、中距离牵制和近身攻击共享同一武器符号。

记忆点：短刃既是投射物，也是近战圣具。

### E. 武器与身份叙事型

**Kunimitsu（《Tekken》）**

Kunimitsu 的设定包括卧底、盗取权限、搜集情报、狐面、双刀和九把诅咒刀。[Bandai Namco 官方资料](https://en.bandainamcoent.eu/tekken/tekken-8/characters/kunimitsu)

战斗体现：忍者工具、盗贼身份和武器收藏共同构成角色幻想。

记忆点：武器来源与角色身份绑定，而不是一把可随意替换的普通刀。

**Tira（《Soulcalibur》）**

Tira 曾属于刺客公会 Bird of Passage，使用环刃，并以舞蹈式攻击姿态形成识别。[Bandai Namco 资料](https://en.bandainamcoent.eu/soulcalibur/news/become-the-hero-of-your-own-legend-soulcalibur-vis-second-story-mode-libra-of-soul)

战斗体现：旋转、舞步、情绪状态和环刃的轨迹相互绑定。

记忆点：非传统刀形与舞蹈动作共同替代了“普通匕首刺客”的视觉语言。

**Kano（《Mortal Kombat》）**

Kano 的蝴蝶刀是系列身份标志，招式中同时存在近身刀法和投掷刀；但他的身份更接近黑帮雇佣兵，而非传统潜行刺客。[《Mortal Kombat: Deadly Alliance》官方遗产页](https://legacy.mortalkombatonline.com/content/games/mkda/kano/)

战斗体现：蝴蝶刀服务于近距离压制和投掷牵制。

记忆点：蝴蝶刀与黑龙组织、义眼和街头犯罪身份绑定。

## 五、刺客型 FTG 角色的阶段结构

| 对战阶段 | 常见系统表现 | 代表先例 |
| --- | --- | --- |
| 中立与探测 | 投掷短刀、有限苦无、远程黑键、墙面移动 | Ibuki、Ciel、Chipp |
| 接近与起攻 | 突进、瞬移、空中下降、侧换、架势切换 | Seth、Taki、Narmaya |
| 压制与连段 | 多段斩击、削防、毒素、资源充能、第二攻击体 | Taki、Maya、Valentine、Zato |
| 场地与布置 | 丝网、喷罐、彩烟、影子、链刃锚点 | Sadira、Kimberly、Zato、Hazama |
| 命中后的继续行动 | 快速重置、追击、再度换位、继续消耗资源 | Chipp、Seth、Vega |
| 失败或资源不足 | 武器掉落、状态切换、危险血表、撤退路线减少 | Maya、Vega、Narmaya、Nagoriyuki |

这里的“刺杀”往往是一次短促的高价值交互，而不是整场战斗都处于隐身状态。角色需要让对手能够看懂风险和反制窗口，否则刺客感会变成单方面的不透明。

## 六、外形与武器的识别关系

外形可以按三个距离层次理解：

1. **远距离轮廓**：面具、发型、环刃、机械装甲、长外套、非对称护具。
2. **中距离身份与功能**：地区、阶层、派系、职业面料、收纳结构和活动关节。
3. **近距离锚点**：手部纹样、护腕、刀柄、面具材质、眼睛、饰物、动作节拍和声音。

《Ghost of Tsushima》的团队明确回避全黑、全布料的传统刺客造型，改用武士甲片和纹样表达人物来源与身份转变。[PlayStation：Ghost of Tsushima 概念设计](https://blog.playstation.com/?p=342594)

《Dishonored 2》从角色年龄、出身、社会位置和职业功能反推服装；Corvo 的外套要支持移动，面具材质和贴脸比例则承担识别作用。[Bethesda：角色美术](https://bethesda.net/en-US/news/dishonored-2-character-art-gallery) [Bethesda：服装设计](https://bethesda.net/en-US/news/dishonored-2-fashion-gallery)

Arc System Works 的开发者问答提出了一个适用于 FTG 的原则：理想情况下，即使只画出角色的粗略涂鸦，也应该能够认出是谁；同时，清晰的视觉形象必须和明确、可学习的玩法风险一致。[Guilty Gear Developer’s Backyard](https://www.arcsystemworks.jp/guiltygear/db/en/volume2.php)

因此，武器记忆点最好反复出现在中立、起攻、压制和退场动作中。只在胜利演出或必杀技中出现的匕首，通常更像装饰；会影响移动、资源、姿态或空间的匕首，才会成为角色语言的一部分。

## 七、共同点与差异轴

### 稳定的共同点

- 先获得信息或制造不确定性，再进入有效距离。
- 进入成功后的收益集中在短时间内。
- 角色通常拥有较强的位移、换位或脱离手段。
- 武器、工具或姿态会改变接近和压制方式。
- 失败后仍然有补救路线，但补救往往带有资源或安全性代价。
- 视觉锚点会在招式动作中反复出现，而不是只停留在设定图上。

### 可以区分角色的差异轴

| 差异轴 | 角色获得的优势 |
| --- | --- |
| 速度 | 让接近和撤离变得难以预测 |
| 距离 | 通过爪、黑键、苦无或链刃管理安全范围 |
| 资源 | 通过库存、充能、掉落或血表制造取舍 |
| 姿态 | 通过收刀、拔刀、持爪或架势改变战斗模式 |
| 空间 | 通过墙面、丝网、喷罐、影子或锚点改变位置关系 |
| 身体武器 | 让武器直接改变轮廓、攻击弧线和叙事身份 |
| 职业工具 | 让毒剂、手术器械、现代喷罐等取代通用忍具 |
| 身份叙事 | 让武器与组织、传承、收藏、诅咒或社会角色绑定 |

## 八、后续阅读和设计讨论时的检查问题

这些问题可以用来比较先例，也可以用来检查未来的角色草案：

1. 角色在中立阶段让对手需要追踪什么：速度、方向、资源、设置物还是姿态？
2. 武器是否同时参与中立、起攻、压制和退场？
3. 武器是否有可观察的持有、掉落、充能、回收或转换状态？
4. 第一次接近失败后，角色是如何重新获得行动权的？代价是什么？
5. 角色的刺客感来自身份、移动、武器、资源还是空间？这些来源是否一致？
6. 如果遮住角色的脸，玩家还能通过轮廓、手部、武器或动作认出他吗？
7. 角色属于“严格刺客”、 “武器型刺客”，还是“刺客相邻的武器战士”？是否需要明确这一区别？

## 九、与当前 FTG Demo 的关系

当前仓库的 FTG Demo 仍然是单角色、单木桩、训练场和确定性战斗会话，暂无 AI、回合流程或完整中立系统。因此，这份文档应作为角色与招式方向的研究背景，不应被理解为已经确定的实现规格。

当前系统已有的帧窗口、命中确认、取消、空中路线和 Combo Solver，适合承载“短促执行”这一部分；真正的“观察、接近、撤离、资源管理和空间控制”还需要在后续角色原型中单独验证。

## 参考资料

### 刺客与潜行设计

- [Game Developer：Stealth in 2D — Design Lessons from Mark of the Ninja](https://www.gamedeveloper.com/design/stealth-in-2d-design-lessons-from-i-mark-of-the-ninja-i-)
- [Ubisoft：The Evolution of Assassin’s Creed Stealth](https://news.ubisoft.com/en-gb/article/1hges9IWLOmNAFpiavYmKl/the-evolution-of-assassins-creed-stealth)
- [Ubisoft：Assassin’s Creed Shadows Stealth Gameplay](https://www.ubisoft.com/en-gb/game/assassins-creed/news/1lmnk4XTnnqRh1foViGYPR)
- [IO Interactive：Hitman Game Modes](https://ioi.dk/hitman?panel=hitman/content/game-modes)
- [PlayStation：Dishonored 创意总监访谈](https://blog.playstation.com/archive/2012/08/21/interview-dishonoreds-harvey-smith-reboots-the-stealth-genre/)
- [Ubisoft：The Evolution of Assassin’s Creed’s Hidden Blades](https://www.ubisoft.com/en-gb/game/assassins-creed/news/5stMcqLQzQ3mckEsP9Aevo/the-evolution-of-assassins-creeds-hidden-blades)
- [Riot：State of Champion Update — Talon](https://nexus.leagueoflegends.com/en-us/2017/01/dev-state-of-champion-update-january-2017/)

### FTG 角色与武器系统

- [UNDER NIGHT IN-BIRTH：Seth 官方角色页](https://www.arcsystemworks.jp/uni2celes/en/character/seth.php)
- [UNDER NIGHT IN-BIRTH：Seth 官方招式说明](https://www.arcsystemworks.jp/uniclr/manual-ps4/en/character/seth.html)
- [Guilty Gear -Strive-：Chipp 官方角色页](https://www.guiltygear.com/ggst/en/character/chp/)
- [Guilty Gear -Strive-：Millia 官方角色页](https://www.guiltygear.com/ggst/en/character/mll/)
- [Guilty Gear -Strive-：Zato-1 官方角色页](https://www.guiltygear.com/ggst/en/character/zat/)
- [Guilty Gear Developer’s Backyard](https://www.arcsystemworks.jp/guiltygear/db/en/volume2.php)
- [Soulcalibur VI：官方战斗调整资料](https://media-center.bandainamcoent.eu/games/soulcalibur6/sc6_battle-adjustment200.pdf)
- [Killer Instinct：Xbox Wire Maya 介绍](https://news.xbox.com/en-us/2014/09/18/games-killer-instinct-season-two-maya/)
- [Killer Instinct：Sadira 官方角色页](https://www.ultra-combo.com/characters/sadira/)
- [Street Fighter V：Ibuki 官方角色页](https://game.capcom.com/cfn/sfv/character/ibuki?lang=en)
- [Street Fighter V：Ibuki 官方招式表](https://game.capcom.com/cfn/sfv/character/ibuki/movelist?lang=en)
- [Street Fighter V：Vega 官方角色页](https://game.capcom.com/cfn/sfv/character/vega?lang=en)
- [Street Fighter V：Vega 官方招式表](https://game.capcom.com/cfn/sfv/character/vega/movelist?lang=en)
- [Street Fighter 6：Kimberly 官方介绍](https://news.capcomusa.com/2022/08/07/the-newcomer-ninja-kimberly-and-thrill-seeking-juri-joins-street-fighter-6/)
- [Granblue Fantasy: Versus：Narmaya 官方角色页](https://granbluefantasyvs.com/characters/narmaya/)
- [Skullgirls：官方角色指南](https://skullgirls.com/guides/Skullgirls_CharacterGuide_EN_X360.pdf)
- [Melty Blood: Type Lumina：官方指令表](https://meltyblood.typelumina.com/resources/img/command/meltyblood_typelumina_all_command_lists_en.pdf)
- [Tekken：Kunimitsu 官方角色页](https://en.bandainamcoent.eu/tekken/tekken-8/characters/kunimitsu)
- [Soulcalibur：Tira 官方资料](https://en.bandainamcoent.eu/soulcalibur/news/become-the-hero-of-your-own-legend-soulcalibur-vis-second-story-mode-libra-of-soul)
- [Mortal Kombat：Kano 官方遗产页](https://legacy.mortalkombatonline.com/content/games/mkda/kano/)
- [Tekken：Nina Williams 官方角色页](https://tekken.com/fighters/nina-williams)

### 外形、武器识别与视觉设计

- [VALORANT：武器设计](https://playvalorant.com/en-us/news/dev/how-the-valorant-arsenal-was-built/)
- [PlayStation：Ghost of Tsushima 概念设计](https://blog.playstation.com/?p=342594)
- [Bethesda：Dishonored 2 角色美术](https://bethesda.net/en-US/news/dishonored-2-character-art-gallery)
- [Bethesda：Dishonored 2 服装设计](https://bethesda.net/en-US/news/dishonored-2-fashion-gallery)
- [Blizzard：Overwatch 概念艺术家访谈](https://news.blizzard.com/en-gb/article/23537427/what-its-like-to-work-on-overwatch-as-a-concept-artist)

### ACGN 与历史参照

- [Fate/Grand Order：Assassin 角色汇总](https://www.fate-go.jp/servant/assassin.html)
- [Journal of Military History：Irregular Warfare in Late Medieval Japan](https://cris.iucc.ac.il/en/publications/irregular-warfare-in-late-medieval-japan-towards-a-historical-und/)
- [Encyclopaedia Iranica：Ismaili Studies](https://www.iranicaonline.org/articles/ismailism-i-ismaili-studies/)
