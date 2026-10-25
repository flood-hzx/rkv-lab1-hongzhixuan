# LAB2：报文处理核独立验证

交付版本：2026-10-25当前源码快照。本文只描述本目录现实现；完整验证结果见[验收说明](验收说明.md)，不包含版本演进记录。

依据实验说明v1.03（2026-10-01）对应阶段要求及§12.5，采用纯SV验证分支和QuestaSim 2021.1等效工具。

## 文件与职责

| 文件 | 当前职责 |
| --- | --- |
| [packet_proc_core.sv](packet_proc_core.sv) | M3：三态FSM、头部检查与payload摘要 |
| [proc_if.sv](proc_if.sv) | 验证接口与独立同步SRAM数组模型 |
| [lab2_pkg.sv](lab2_pkg.sv) | packet、参考计算、基类和六个独立测试类 |
| [tb_lab2.sv](tb_lab2.sv) | 时钟、选例、实际输出监视和超时 |
| [Makefile](Makefile)、compile.do、run.do、batch.do、wave.do | 编译、选例、批量运行、失败返回及GUI显示 |
| [TESTPLAN.md](TESTPLAN.md)、[验收说明.md](验收说明.md) | 检查目标、输入/期望/实际结果、对应证据 |
| [逻辑与语法讲解.md](逻辑与语法讲解.md) | 当前语言/方法和信号路径解释 |

## 实现与检查约定

M3按IDLE→PROCESS→DONE工作；start被接受的第一沿busy=1、done=0，清除上一帧结果并采样配置。DONE保持到下一start或复位。同步读使用response_valid/response_index对齐返回，末字只计算有效payload byte，sum截断8位。

八字数组模型替代M2，本Lab不依赖Lab1。公共package/基类由六个独立测试类复用；动态payload数组、定长word数组、期望队列、按名称索引的关联统计均参与实际检查。队列和启动/完成数在结束时对账。

数据按Word0={pkt_len,pkt_type,flags,hdr_chk}高字节在前组织，flags激励为0。exp_pkt_len=0表示未配置；非法长度只处理头部后完成，三类错误独立判断。SEED进入仿真器及日志，但本Lab是定向数据，不把换seed说成约束随机验证。

## 运行入口

在本Lab目录执行；从四个Lab共同上级目录可用make -C lab2加相同目标。每次run自动编译，不能靠旧缓存通过。

    make smoke
    make regress
    make run TESTNAME=type SEED=1
    make rung TESTNAME=type SEED=1

TESTNAME对应实际测试类，未知名称失败。SEED用于单次run，本Lab数据为定向生成。

RUN_ID省略或为AUTO时自动生成。证据使用current_20261025等归档ID；重跑需用自动ID或新ID，不能覆盖已归档输出。

新日志：logs/RUN_ID/测试名_seed/compile.log及run.log；WLF：waves/RUN_ID/测试名_seed.wlf。相同ID可含不同测试/seed，重复目标会拒绝覆盖。只编译的make comp另建compile目录。

## 当前版本证据

本目录只携带这份源码重新生成的日志、波形及报告。[验收说明](验收说明.md)列明实际用例、seed、命令与结果。

交付版.gitignore仅忽略缓存与临时文件，保留必要日志/WLF/覆盖数据库，避免提交时漏掉验收证据。本人串讲、组队贡献和教师评分仍需现场完成。
