# PPA-Lite Lab1–4（普通 SystemVerilog 分支）

依据[2026秋实验说明v1.03](https://shimo.im/docs/ne4G8wuji0D0NqCJ/)与[课程说明v1.04](https://shimo.im/docs/EsciCi4G04Msraf7/)。Lab1/2保持此前提交版本；Lab3/4为2026-10-28审阅的当前普通SV实现。本仓库交付普通SV四阶段，UVM对照分支单独保留在本地。

| 阶段 | 源码与验证职责 | 实际回归 |
| --- | --- | --- |
| [Lab1](lab1/README.md) | M1 APB/CSR/IRQ + M2一写两读SRAM；基础module/interface TB | regress三个seed，389项检查/seed |
| [Lab2](lab2/README.md) | M3包处理算法核；独立数组模型与六个测试类 | 6/6，16帧、244项检查 |
| [Lab3](lab3/README.md) | 真实M1/M2/M3纯连线Top；分层SV环境与独立输入参考模型 | 7/7，24帧、13,689项检查 |
| [Lab4](lab4/README.md) | 复用同一系统和验证环境；功能覆盖、代码覆盖及缺口补测 | 12/12，48帧完成、1帧复位中止、29,751项检查 |

各阶段保留源码、接口/包/TB、Make/Tcl、TESTPLAN、验收说明与对应日志/WLF。Lab4另有原始/过滤UCDB、文本和HTML报告、过滤Excel。没有编译缓存、其他练习、历史版本或审阅工具依赖。

## 从仓库根目录运行

实测为QuestaSim 2021.1、GNU Make 3.81；命令行需能找到vsim/vlog/vcover、make和Makefile使用的shell工具，仿真许可证按本机工具配置。

```sh
make -C lab1 smoke
make -C lab1 regress
make -C lab2 smoke
make -C lab2 regress
make -C lab3 smoke
make -C lab3 regress
make -C lab4 smoke
make -C lab4 regress
make -C lab3 run TESTNAME=random SEED=123
make -C lab4 cov COVSET=baseline
make -C lab4 mergecov COVSET=baseline
make -C lab4 cov COVSET=final
make -C lab4 mergecov COVSET=final
make -C lab4 verdicov COVSET=final
```

每次run自动处理编译；使用AUTO或新RUN_ID/MERGE_ID，不能覆盖已归档结果。Lab1单次选例参数为TEST，Lab2起为TESTNAME。GUI仿真用各Lab的make rung，波形布局由wave.do加载。

## 四阶段如何连成同一个项目

Lab3/4直接编译lab1/apb_slave_if.sv、lab1/packet_sram.sv、lab2/packet_proc_core.sv，并使用唯一的lab3/ppa_top.sv和ppa_if.sv；Top只负责统一时钟复位和端口连接，不复制另一套算法或状态。M1和M3使用M2独立同步读口。完成时M3的DONE/结果/错误传回M1，当前完成经M1组合IRQ资格路径可见，随后保存至W1C历史状态。

系统回归实际执行APB写包→配置→START→真实M2/M3处理→读STATUS/RES/ERR/IRQ→W1C；独立参考模型从成功APB输入重建期望，并分别比较实际完成结果及总线读回。Lab4的csr/memory/errors与smoke/frames/status/busy/irq等清单覆盖前面阶段必做和已实现选做，不能只用单模块PASS证明系统正确。

Lab3随机/扩展和Lab4 coverage/closure只针对代表性边界、集成风险与实际覆盖缺口，不把全部字段组合穷举作为要求。当前待提交四Lab放在单独公共父目录中又完整回归通过，核对了真实共享源码、编译顺序、状态/IRQ时序和结束对账。

## 覆盖与验收材料

当前源码重新采集的Lab4 baseline/final见[验收说明](lab4/验收说明.md)、[TESTPLAN](lab4/TESTPLAN.md)和[覆盖率汇总](lab4/reports/coverage_summary.md)。功能覆盖69/69有效bin；原始statement/line 99.37%、branch 98.94%、condition 100%、FSM状态/转移100%、toggle 99.71%。原始和登记过滤后的值分别保留，没有取五类平均数掩盖不足。

登记过滤仅涉及不可达非法状态恢复分支和恒定PREADY；过滤后各项100%，仍待助教确认口径。[Excel](lab4/覆盖率过滤登记表.xlsx)、exclusions.do、原始数据库及报告可逐项核对。本人串讲、分工、答辩和教师评分按课程现场要求进行。
