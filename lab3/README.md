# LAB3：真实PPA集成与分层SV验证

交付版本：2026-10-25当前源码快照。本文只描述本目录现实现；完整验证结果见[验收说明](验收说明.md)，不包含版本演进记录。

依据实验说明v1.03（2026-10-01）对应阶段要求及§12.5，采用纯SV验证分支和QuestaSim 2021.1等效工具。

## 文件与职责

| 文件 | 当前职责 |
| --- | --- |
| [ppa_top.sv](ppa_top.sv) | 真实M1/M2/M3纯连线和统一时钟复位 |
| [ppa_if.sv](ppa_if.sv) | APB接口、驱动时序与只读观察信号 |
| [lab3_pkg.sv](lab3_pkg.sv) | 随机事务、driver/monitor/参考模型/scoreboard及测试类 |
| [tb_lab3.sv](tb_lab3.sv) | 真实DUT与SV环境入口 |
| [Makefile](Makefile)、compile.do、run.do、batch.do、wave.do | 编译、选例、批量运行、失败返回及GUI显示 |
| [TESTPLAN.md](TESTPLAN.md)、[验收说明.md](验收说明.md) | 检查目标、输入/期望/实际结果、对应证据 |
| [设计与验证思路.md](设计与验证思路.md) | 当前语言/方法和信号路径解释 |

## 实现与检查约定

Top仅连线，统一PCLK/PRESETn，M1和M3分别使用M2独立同步读口。直接编译相邻正式Lab1/2源码。

测试类→packet/mailbox→APB driver→真实DUT→monitor→独立参考模型/scoreboard构成完整检查链。期望由已接受APB写账本和规格计算，实际输出与APB读回分别检查。M1 START沿后出现，M3下一上升沿接受；monitor区分沿前APB返回与沿后状态。

rand/constraint/randomize和std::randomize均检查返回值；负向包显式放开相应合法约束。有限任务用fork...join，完成/超时用有归属的join_any及清理，monitor/scb后台join_none并在最终停止和排空。继承/virtual扩展场景，共享同一环境。

提交、接受、完成/复位中止及driver计数一致，mailbox排空才置test_done。只有实际忙期拒写和真实busy/done STATUS读才能满足相应用例，避免空测。

## 运行入口

在本Lab目录执行；从四个Lab共同上级目录可用make -C lab3加相同目标。每次run自动编译，不能靠旧缓存通过。

    make smoke
    make regress
    make run TESTNAME=random SEED=1
    make rung TESTNAME=random SEED=1

TESTNAME对应实际测试类，未知名称失败。SEED用于单次run，regress的种子列表使用SEEDS，例如SEEDS="1 123"。

RUN_ID省略或为AUTO时自动生成。证据使用current_20261025等归档ID；重跑需用自动ID或新ID，不能覆盖已归档输出。

日志与WLF分别在logs/RUN_ID/及waves/RUN_ID/；批量入口为各测试/seed派生ID。编译库work_lab3是可再生成缓存。

## 相邻依赖

保留同级lab1、lab2、lab3、lab4结构。Lab3/4引用lab1/apb_slave_if.sv、lab1/packet_sram.sv、lab2/packet_proc_core.sv；Lab4另引用Lab3 Top/interface/package。不同阶段共享一份正式RTL，不复制修改另一套硬件。

## 当前版本证据

本目录只携带这份源码重新生成的日志、波形及报告。[验收说明](验收说明.md)列明实际用例、seed、命令与结果。

交付版.gitignore仅忽略缓存与临时文件，保留必要日志/WLF/覆盖数据库，避免提交时漏掉验收证据。本人串讲、组队贡献和教师评分仍需现场完成。
