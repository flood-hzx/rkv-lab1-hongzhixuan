# Lab4：普通 SystemVerilog分支

按[实验说明v1.03](https://shimo.im/docs/ne4G8wuji0D0NqCJ/) §11.5、§12.3–12.5实现。2026-10-28重新审阅当前源码、配套脚本并从无缓存目录实际回归。本轮只更新说明和结果材料，RTL、TB、验证包及运行脚本保持原样。

本目录使用普通类、mailbox、virtual方法和显式线程收尾。测试、驱动、监视和独立结果检查职责分开。验收所需语法/方法对应关系见[验收说明](验收说明.md)。

## 运行

从各Lab共同上级目录执行；进入本目录后可省略`-C lab4`：

```sh
make -C lab4 comp
make -C lab4 smoke
make -C lab4 regress
make -C lab4 run TESTNAME=random SEED=123
make -C lab4 rung TESTNAME=frames SEED=1
```

TESTNAME选择实际测试类。SEED用于单次run，SEEDS用于批量回归。未知测试、随机化失败、超时、结果失配、检查未完成都会失败。每次run自动编译；不依赖旧work缓存。RUN_ID省略或AUTO会自动生成，归档结果不可覆盖。

正式源码与脚本均在本目录顶层。测试目标、输入、期望及实际结果见[TESTPLAN](TESTPLAN.md)、[验收说明](验收说明.md)。当前正常回归使用`RUN_ID=review_20261028`，完整输出在[回归日志](logs/review_20261028_console.log)，逐测试日志在logs/，波形在waves/对应RUN_ID目录。

## 覆盖率

```sh
make -C lab4 cov COVSET=baseline
make -C lab4 mergecov COVSET=baseline
make -C lab4 cov COVSET=final
make -C lab4 mergecov COVSET=final
make -C lab4 verdicov COVSET=final
```

baseline包含10项，final增加coverage、closure，共12项。仅真实DUT四个module插桩；功能覆盖单独报告。覆盖在实际完成/ACCESS被检查后采样，复位中止不计完成。两套分支的数据库独立生成、独立合并。

当前数据库在coverage/，报告在reports/baseline/review_20261028和reports/final/review_20261028；保留raw和filtered。默认查看按修改时间选本COVSET最近filtered数据库，也可用COVDB指定raw/filtered。覆盖率模型、缺口和补测见[TESTPLAN](TESTPLAN.md)及[验收说明](验收说明.md)。[过滤Excel](覆盖率过滤登记表.xlsx)与exclusions.do一致，技术过滤口径仍待助教确认。

## 共享依赖和环境

保持同级lab1、lab2、lab3目录：M1/M2来自lab1，M3来自lab2，Top/interface来自lab3。Lab4另复用Lab3同分支的验证包；普通SV四Lab可整体放在任意公共父目录下运行，不依赖try目录名、外部审查工具或历史备份。

实测工具是QuestaSim 2021.1、GNU Make 3.81。日志/WLF及Lab4原始UCDB/报告属于验收材料；work、transcript和临时文件属于可重建缓存。本人讲解、分工与教师评分仍按课程验收。
