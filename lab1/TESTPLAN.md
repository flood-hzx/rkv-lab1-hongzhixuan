# Lab1 简明 testplan 与验收对照

依据：[实验文档](https://shimo.im/docs/ne4G8wuji0D0NqCJ/)的 **§11.2、§12中Lab1一栏**。仅针对M1/M2与基础TB，不做全地址、全状态组合穷举，也不引入后续Lab内容。

本表对应本交付件当前源码；结果由本版本重新运行，证据ID为current_20261025。

## 1. 功能测试计划

| 项目 | 代码/用例 | 输入摘要 | 期望与检查点 | 命令及证据 |
| --- | --- | --- | --- | --- |
| 必做1：默认值与APB时序 | defaults_test、control_test、interface.transfer、monitor | 复位；读CSR；写CTRL/CFG | CTRL=0、CFG=F1、STATUS=0；SETUP到ACCESS地址/方向/数据保持；PREADY=1 | `make smoke`；[smoke日志](logs/current_20261025/smoke_1/run.log)、[对应WLF](waves/current_20261025/smoke_1.wlf) |
| 必做2：八字写入映射 | memory_test、monitor | 040/044/…/05C写八个不同word | we有效、索引0~7、wdata匹配；两读口读回正确；proc读不早于上升沿 | `make run TEST=memory`；现有新版本证据包含在[smoke日志](logs/current_20261025/smoke_1/run.log)的packet_memory段 |
| 必做3：结果读回与译码 | results_test、defaults_test、M1读case | 两组len/type/sum/xor stub；默认值用例访问全部CSR | 018/01C/020/024读回一致；有效位外补0；按CSR表和内存窗口译码 | `make run TEST=results`；现有新版本证据包含在[smoke日志](logs/current_20261025/smoke_1/run.log)的result_stubs段 |
| 选做4：访问错误 | errors_test | 写六个RO、访问02C/060/041、busy写040 | PSLVERR=1且RO原非零值/内存不变；busy时合法内存读和普通CSR访问仍允许 | `make run TEST=errors`；[regress日志](logs/current_20261025/regress_1/run.log)的errors段 |
| 选做5：完整IRQ | irq_test | EN配置；无错/带错done事件；STA写0/1/2/3 | EN读写；pending保持；W1C；00/01/10/11四种pending对应正确OR输出 | `make run TEST=irq`；[regress日志](logs/current_20261025/regress_1/run.log)的irq段 |
| IRQ周期时序检查 | irq_cycle_test、cycle_completion、check_irq_cycle | 上升沿用NBA发布完成；首次保存沿W1C；W1C沿后新完成 | 下一沿前IRQ_STA组合读数据与irq_o正确、saved尚为0；下一沿保存；写0保持；关闭使能保留saved；持续done不重触发；旧提交不覆盖清除，新完成仍可见 | `make run TEST=irq_cycle`；[irq_cycle日志](logs/current_20261025/irq_cycle_1/run.log)、[对应WLF](waves/current_20261025/irq_cycle_1.wlf)；读值见[验收说明第11节](验收说明.md) |
| 代表性扩展：数据模式/边界 | patterns_test | 0、全1、交替位、一组随机值；重写首末word | CFG按F1、PKT_LEN_EXP按3F、IRQ_EN按03保存；首末读回新值 | `make run TEST=patterns SEED=123`；[seed=123 regress日志](logs/current_20261025/regress_123/run.log)的patterns段 |
| 代表性扩展：输入变化/双读 | results_test、memory_test | 两组结果；两读口读不同word | 结果不是固定值；读口各自正确 | 包含在smoke和regress中 |

命令中的单项入口均由当前TB和脚本支持；证据栏若引用smoke/regress中的同一用例，不表示2026-10-20另跑过该单项命令。

## 2. 当前入口、结果与证据位置

- `make smoke`：defaults、control、memory、results。
- `make regress`：按seed 1、123、2026运行上述基础用例，再加patterns、errors、irq、irq_cycle。
- `make run TEST=名称 SEED=正整数`：支持smoke、regress、defaults、control、memory、results、patterns、errors、irq、irq_cycle；未知名称失败。
- 新结果按RUN_ID隔离：日志为logs/RUN_ID/测试名_seed/compile.log及run.log，波形为waves/RUN_ID/测试名_seed.wlf，Make入口另保存控制台日志。每次使用新ID，不重用已存在的测试/seed输出。

2026-10-20已有结果：smoke seed=1为112项；regress seed=1/123/2026各389项；单独irq_cycle seed=1为115项，均PASS且编译/仿真0 errors、0 warnings。详见[验收说明第11节](验收说明.md)。

`[CASE_PASS]`的checks是该用例增量，`[PASS]`是全流程总数，还包括最后一次SETUP/ACCESS计数比较。例如irq_cycle用例内114项，单独运行总数115项。检查数量不是得分依据，monitor的逐拍判断也不全部计入checks。

地址完整性不通过遍历4096个地址证明：M1的CSR分类/读写case逐一对应规格表，内存条件同时限制040~05C与四字节对齐；基础测试访问全部有效CSR和八个word，并验证代表性保留、越界、非对齐地址。

## 3. ABCD的适用证据

| 维度 | 本Lab需要说明什么 | 本工程证据 |
| --- | --- | --- |
| A. 本阶段语法/方法学的有效应用（8） | 定位与合理职责4、真实使用及关键机制解释4 | [tb_lab1.sv](tb_lab1.sv)的事务字段真实驱动/比较；地址与期望函数实际调用，日志有期望/实际值 |
| B. 语言与验证方法的递进理解（5） | 相对前置Verilog新增/复用/改进3、选择理由2 | [验收说明.md](验收说明.md)第3、7节；解释接口和类型组织，不提前引入类环境 |
| C. 扩展测试与结果分析（7） | 可复现有目标扩展3、动机/边界/风险2、真实结论及局限2 | 代表性扩展；当前版本的数据模式、首末覆盖写与IRQ交接检查，不穷举错误 |
| D. 验证工程的完整配合（5） | 职责复用2、入口依赖2、日志退出/目录摘要1 | [Makefile](Makefile)、[run.do](run.do)、[batch.do](batch.do)；已有实跑及WLF离线读取记录，未知入口和防覆盖自检，不把未执行检查算通过 |

## 4. 现场展示的简短顺序

1. `make smoke`，展示默认值及SETUP/ACCESS波形。
2. 在M2_WRITE组查看八次we/index/data，说明`index=(PADDR-040)/4`。
3. 说明四个RES输入来自stub，并查看读回值。
4. `make rung TEST=errors`展示错误响应与无写副作用。
5. `make rung TEST=irq_cycle`展示完成周期可见值与下一沿saved，再用`TEST=irq`展示OR输出与分位W1C。
6. 用patterns的一条日志说明扩展目的，再结合接口和类型解释ABCD。

以上是展示步骤，不是本次已执行GUI操作的记录。
