# LAB4：全系统回归与覆盖率闭环

交付版本：2026-10-25当前源码快照。本文只描述本目录现实现；完整验证结果见[验收说明](验收说明.md)，不包含版本演进记录。

依据实验说明v1.03（2026-10-01）对应阶段要求及§12.5，采用纯SV验证分支和QuestaSim 2021.1等效工具。

## 文件与职责

| 文件 | 当前职责 |
| --- | --- |
| [lab4_pkg.sv](lab4_pkg.sv) | 功能覆盖组件和coverage/closure补测类 |
| [tb_lab4.sv](tb_lab4.sv) | 复用Lab3环境，绑定覆盖组件与选例 |
| [Makefile](Makefile)、compile.do、run.do、batch.do、wave.do | 编译、选例、批量运行、失败返回及GUI显示 |
| [TESTPLAN.md](TESTPLAN.md)、[验收说明.md](验收说明.md) | 检查目标、输入/期望/实际结果、对应证据 |
| [设计与覆盖率思路.md](设计与覆盖率思路.md) | 当前语言/方法和信号路径解释 |

## 实现与检查约定

复用正式M1/M2/M3/Top及Lab3的SV环境、参考模型和scoreboard。覆盖组件在实际ACCESS和正常完成结果检查通过后采样；复位中止不计作完成帧。

frame_cg与access_cg共17个覆盖点/交叉、69个有效bin。五类DUT代码覆盖率分别统计，FSM状态/转移分别展示；功能组均值不当作代码覆盖率。

baseline使用前10项测试，final增加coverage和closure。coverage补功能边界/配置/交叉缺口；closure补可达复位转移及数据双向跳变。缺口与补测前后结果见TESTPLAN和验收说明，未用过滤代替可达场景。

过滤仅M3不可达非法状态恢复行、Top/M1恒定PREADY，以及两个规格不合法的功能cross组合；Excel与exclusions.do保留。原始和过滤结果并列，过滤审批仍由助教确认。

## 运行入口

在本Lab目录执行；从四个Lab共同上级目录可用make -C lab4加相同目标。每次run自动编译，不能靠旧缓存通过。

    make smoke
    make regress
    make run TESTNAME=coverage SEED=1
    make rung TESTNAME=coverage SEED=1

TESTNAME对应实际测试类，未知名称失败。SEED用于单次run，regress的种子列表使用SEEDS，例如SEEDS="1 123"。

覆盖率使用同一套源码与环境：

    make cov COVSET=baseline
    make mergecov COVSET=baseline
    make cov COVSET=final
    make mergecov COVSET=final
    make verdicov COVSET=final

默认按文件修改时间选择本COVSET最近的filtered数据库；用COVDB可明确指定raw或filtered。手工run.do第四参数仅允许normal或coverage。

RUN_ID省略或为AUTO时自动生成。证据使用current_20261025等归档ID；重跑需用自动ID或新ID，不能覆盖已归档输出。

日志与WLF分别在logs/RUN_ID/及waves/RUN_ID/；批量入口为各测试/seed派生ID。编译库work_lab4是可再生成缓存。

## 相邻依赖

保留同级lab1、lab2、lab3、lab4结构。Lab3/4引用lab1/apb_slave_if.sv、lab1/packet_sram.sv、lab2/packet_proc_core.sv；Lab4另引用Lab3 Top/interface/package。不同阶段共享一份正式RTL，不复制修改另一套硬件。

## 当前版本证据

本目录只携带这份源码重新生成的日志、波形及报告。[验收说明](验收说明.md)列明实际用例、seed、命令与结果。

交付版.gitignore仅忽略缓存与临时文件，保留必要日志/WLF/覆盖数据库，避免提交时漏掉验收证据。本人串讲、组队贡献和教师评分仍需现场完成。
