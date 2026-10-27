# Lab4 Testplan

依据实验说明v1.03 §11.5、§12.3。2026-10-28当前源码已独立重新完成12项正常回归和baseline/final覆盖采集；各PASS来自真实APB/DUT/monitor/scoreboard检查，复位中止单独对账。当前命令与证据见[验收说明](验收说明.md)和[本轮完整输出](logs/review_20261028_console.log)。

默认 `SEEDS=1`、`SEED=1`。`COVSET=baseline` 的初始测试列表为 `smoke frames status busy irq errors csr memory random extension`；`COVSET=final` 在相同列表后增加 `coverage closure`。`regress` 用于正常回归，`cov` 用于相同测试集的代码覆盖率采集；二者的结果不能互相替代。

| testcase | 检查点 | 输入摘要 | 期望与自动检查 | PASS/FAIL 结果证据 | 功能 bin / seed | 缺口处理 |
| --- | --- | --- | --- | --- | --- | --- |
| `smoke` | 完整端到端数据路径、APB 与 IRQ | 8B/type02，payload 01/02/03/04 | scoreboard 重建输入并核对完成结果；APB RES 读回一致；检查 IRQ 闭环 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | 主要贡献 access 地址/方向/响应、结果类 bin；默认 seed 1 | 如失败先定位链路/参考模型；如功能覆盖缺失记入 baseline 缺口表 |
| `frames` | 连续帧隔离，第二帧不得沿用旧结果 | 同一仿真依次发送 8B/type01、13B/type08 | 两帧各自真实完成并与独立期望比较；新 START 清除旧状态/结果 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | `cp_sequence.consecutive_frame`，帧长度/类型；默认 seed 1 | 以实际 frame bin 报告确认，不以“提交两帧”代替完成采样 |
| `status` | BUSY/DONE 状态真实读回 | 32B/type04；处理中和完成后读 STATUS | ACCESS 时刻读到 BUSY、DONE 对应状态；两种读操作均实际发生 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | access 的 `result_or_status`、read；默认 seed 1 | 检查实际 ACCESS 样本和 scoreboard 计数；缺少一类就补触发时序 |
| `busy` | BUSY 期间 PKT_MEM 写保护 | 处理 32B/type02 时写 word7=DEADBEEF | 记录 ACCESS 前 busy=1、错误响应；随后读回 word7 原值，帧摘要不变 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | `busy_write_rejected`、PKT_MEM、write/rejected；默认 seed 1 | 若未实际落在 busy 周期则 testcase 不满足；“busy 写被接受”是违规，不是待命中 bin |
| `irq` | IRQ enable、pending 事件与 W1C 分位清除 | EN=00 正常帧、EN=01 正常帧、EN=11 坏校验帧；清零/分别清位 | 禁用不置位；完成/错误事件按 EN 保存；W1C 只清目标位；IRQ_STA 和 irq 输出一致 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | `enable_none/done/error/both`、`clear_none/done/error/both` 及清除结果；默认 seed 1 | 依据逐项覆盖缺口补测；不要把写入寄存器等同于事件已产生 |
| `errors` | 非法地址、只读写保护、错误响应 | 对非法地址/只读寄存器发访问，并检查响应 | APB 错误响应符合规格；错误访问不产生非预期状态/数据改动 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | access `other`、rejected、read/write；默认 seed 1 | 若目标地址类未命中，针对性增加已检查的访问；记录过滤/不可达理由 |
| `csr` | CSR 默认值、字段属性与保留位行为 | 读默认值；对可写、只读及保留字段读写代表性模式 | 实际 APB 返回符合字段属性和保留位掩码；只读非法写由errors另测 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | access 各 CSR 地址、方向、响应；默认 seed 1 | 结合逐地址报告补测，不扩大成所有32位值穷举 |
| `memory` | PKT_MEM 字写读、首末位置及覆盖写 | 对 8 个字地址写入/读回，包含首末字与覆盖写 | 八字初次读回及首末覆盖写读回与独立账本一致；busy写保护另测 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | access `packet_memory`、read/write、idle memory write；默认 seed 1 | 以真实 ACCESS 观察为准补边界地址；busy 期间写由 `busy` 专项覆盖 |
| `random` | 受约束随机探索合法帧及不同帧间隔 | 每 seed 12 帧；长度 4–32、四种合法类型、随机 payload/mode；mask=F | 每次随机化成功；每帧 scoreboard 比对、APB 结果读回与 IRQ 检查通过；同 seed 可复现 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | 广泛探索合法组合；默认 seed 1，扩展 seed 由正式运行命令记录 | 随机测试补广度，不保证命中稀有 bin；按 uncovered 功能 bin 加定向补测 |
| `extension` | 字节尾部、摘要累加、期望长度与多错误 | 7B FE/05/03；13B 九个 AA；12B 期望 8；受控 3B/type03/坏校验 | 对应 sum/XOR 为 06/F8、FA/AA；后两帧分别长度错及多错误，仍正常完成并核对 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | expected mismatch、length/type/checksum error 与 multiple errors；默认 seed 1 | 以 scoreboard 可接受的真实负向结果补缺，不覆盖 checker 必须拒绝的失配观察 |
| `coverage`（仅 final） | 对功能覆盖报告中的目标缺口做少量、有检查的补测 | 共 14 帧：长度 3/4/8/12/16/32/33；四类合法类型与非法 type03；校验开/旁路及坏校验；mask=F/E/0；期望长度未配/匹配/不匹配；IRQ 四种 EN；BUSY 探测、部分清 IRQ、连续帧 | 每个定向 packet 仍走真实 driver/DUT/monitor/scoreboard；随机化失败或结果不一致均 fatal；报告逐 coverpoint/cross 缺口 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | 填补 `frame_cg` 的长度/类型/mode/mask/permission/expected length/IRQ/outcome/error/sequence 与 `length_by_outcome`；同时贡献 APB 类 bin；SEED=1 | 两个越界长度通过组合 `ignore_bins` 说明规格不可达；非法结果/漏帧/忙写被接受为 `illegal_bins`，不是达标目标。其余缺口须以实际报告为准，说明补测或有依据的过滤理由 |
| `closure`（仅 final） | 原始代码报告的复位转移、头字段高位与同步读数据跳变缺口 | APB读全1再读0；255B/typeFF、0B、32B、8B全FF；DONE复位；最后一帧PROCESS中复位 | 4帧结果比较通过，1帧按复位明确中止并单独对账；默认CSR恢复；busy重复START不得新增一帧；所有未中止帧仍经APB读结果 | PASS（SEED=1）；[验收说明](验收说明.md)、[reports/](reports/) | 长度越界、非法类型、mask=0、exp=63与匹配，FIRST/连续帧；seed 1 | 补测真实可达的FSM两条复位转移与数据跳变，不以过滤替代测试；仅不可达default分支与常量PREADY另登记 |

## 当前版本执行结果

本次十二项正常兼容性回归见[验收说明](验收说明.md)；2026-10-28重新采集的baseline/final覆盖率及补测对照见[覆盖率汇总](reports/coverage_summary.md)。当前覆盖率报告对应本轮源码，本次正常回归、覆盖率采集和合并均从当前源码重新执行。
