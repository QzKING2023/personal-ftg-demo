# 07: 全量终证与分片触发判定

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 04, 06(05 若实施则加)

## What to build

整个提速工程的收口:一次**冷跑**全量(全新缓存文件或基线模式)证明墙钟 ≤1 小时,与 02 的串行基线做最终对拍,并依据最长 job 的实测耗时作出 job 内请求分片的触发判定。这是全工程唯一一次"证明性"全量运行——此前的门都用定向 job。

## User stories covered

20, 21, 22(判定)。

## Acceptance criteria

- [ ] 冷跑全量完成:新缓存文件(或 `--acceptance-no-reuse`),并行模式,墙钟 ≤1h;summary、状态文件、耗时归档到本票 scratch 验收目录。
- [ ] 最终对拍:与 02 串行基线的 fingerprint 集合、断言总数、各 job 结论逐项相等。
- [ ] 最长 job 耗时记录;>20min 则创建分片票(重 job 唯一请求按摘要 fan-out 到多进程,复用 06 的 fragment 合并做去重),否则记录"不触发"与数据。
- [ ] 更新量级基线:新耗时结构写回 spec 的 Further Notes 或 Comments(供后续票据估计验收时长)。
- [ ] 旧 PS runner 的去留决定:保留为历史基线或删除,记录理由(倾向保留至下一次全绿后再删)。

## Blocked by

- 04
- 06
- 05(若实施)
