# LAB1：APB接口与同步SRAM

交付版本：2026-10-25当前源码快照。本文只描述本目录现实现；完整验证结果见[验收说明](验收说明.md)，不包含版本演进记录。

依据实验说明v1.03（2026-10-01）对应阶段要求及§12.5，采用纯SV验证分支和QuestaSim 2021.1等效工具。

## 文件与职责

| 文件 | 当前职责 |
| --- | --- |
| [apb_slave_if.sv](apb_slave_if.sv) | M1：APB/CSR/存储窗口/中断 |
| [packet_sram.sv](packet_sram.sv) | M2：8×32-bit、一写两同步读 |
| [tb_lab1.sv](tb_lab1.sv) | APB接口、类型、独立TB与检查 |
| [Makefile](Makefile)、compile.do、run.do、batch.do、wave.do | 编译、选例、批量运行、失败返回及GUI显示 |
| [TESTPLAN.md](TESTPLAN.md)、[验收说明.md](验收说明.md) | 检查目标、输入/期望/实际结果、对应证据 |
| [逻辑与语法讲解.md](逻辑与语法讲解.md) | 当前语言/方法和信号路径解释 |

## 实现与检查约定

范围为M1、M2、基础过程式TB、三个必做和两个已完成选做。处理核状态/结果由TB stub提供；本Lab不声称验证真实M3算法。APB在下降沿驱动、ACCESS上升沿采样；M2的APB读在SETUP预取以满足PREADY固定1。

START使用写前enable资格，软件先写CTRL=1再写CTRL=3。M1完成/错误IRQ在新done出现周期组合可见，下一PCLK保存；pending保持到W1C。IRQ_EN与新完成同沿时组合判断使用更新后的使能。真实集成中M3的done、结果和错误保持到下一合法START；不额外要求任意异步短脉冲。W1C不能被首次延迟保存覆盖，持续高done不重触发。

TB实际使用module/interface/string/typedef/enum/struct/function/task；monitor核对SETUP/ACCESS和八字写接口，比较拒绝X/Z。扩展为代表性字段模式、首末覆盖写、双读和IRQ交接，不穷举。

实验§5/附录A/C允许W1P启动，与§8.3将W1P并入写报错的表述存在歧义；本实现保留合法START，未把这处歧义解释为禁止全部启动。

## 运行入口

在本Lab目录执行；从各Lab共同上级目录可用make -C lab1加相同目标。每次run自动编译，不能靠旧缓存通过。

    make smoke
    make regress
    make run TEST=irq_cycle SEED=1
    make run TEST=patterns SEED=123
    make rung TEST=smoke SEED=1

TEST可选smoke、regress、defaults、control、memory、results、patterns、errors、irq、irq_cycle。regress固定跑seed 1/123/2026；只指定一次完整回归时用make run TEST=regress SEED=N。

RUN_ID省略或为AUTO时自动生成。证据使用current_20261025等归档ID；重跑需用自动ID或新ID，不能覆盖已归档输出。

新日志：logs/RUN_ID/测试名_seed/compile.log及run.log；WLF：waves/RUN_ID/测试名_seed.wlf。相同ID可含不同测试/seed，重复目标会拒绝覆盖。只编译的make comp另建compile目录。

## 当前版本证据

本目录只携带这份源码重新生成的日志、波形及报告。[验收说明](验收说明.md)列明实际用例、seed、命令与结果。

交付版.gitignore仅忽略缓存与临时文件，保留必要日志/WLF/覆盖数据库，避免提交时漏掉验收证据。本人串讲、组队贡献和教师评分仍需现场完成。
